-- shopify_sales_over_time - recreates Shopify's "Total sales over time"
--
-- Grain: day x store x order x location x channel x row type. Keeping row type
-- in the grain means a day where an order both sells and refunds produces two
-- rows, so the SALE and RETURN sides stay independently auditable.
--
-- Multi-store safe: order IDs are only unique WITHIN a store, so shopify_store is
-- part of every join key and of the grain. Drop it from one join and rows fan out
-- across storefronts silently.
--
-- Event-based: reads Shopify's order agreement log, so every financial change
-- lands on the day it happened - returns on the refund date, order edits on the
-- edit date. History does not restate itself when an old order is refunded.
--
-- Currency: shop money, plus the presentment amounts the customer actually paid.
-- Timezone: read from the shop record, so nothing needs hardcoding.
--
-- Depends on: stg_shopify__order, .order_agreement, .order_agreement_sale,
--             .order_line, .order_refund, .order_line_refund, .shop, .location

{{ config(
    materialized='table',
    partition_by={'field': 'date', 'data_type': 'date', 'granularity': 'month'}
) }}

WITH shop AS (
    -- Per store: currency and timezone both vary between storefronts.
    SELECT
        shopify_store,
        ANY_VALUE(currency)                       AS shop_currency,
        COALESCE(ANY_VALUE(iana_timezone), 'UTC') AS report_timezone
    FROM {{ ref('stg_shopify__shop') }}
    GROUP BY shopify_store
),

locations AS (
    SELECT shopify_store, location_id, location_name, location_country_code
    FROM {{ ref('stg_shopify__location') }}
),

orders AS (
    SELECT
        o.shopify_store,
        o.order_id,
        o.order_name,
        o.location_id,
        o.source_name,
        o.financial_status,
        o.fulfillment_status,
        o.cancelled_at,

        -- The order's own currency wins over the shop's CURRENT currency, which
        -- may have changed since. Deliberately NOT falling back to presentment
        -- currency: that is what the customer was charged in, so using it here
        -- would label shop-currency money with the buyer's currency. If none of
        -- these is set, NULL is the honest answer - a guessed currency code
        -- silently mislabels every amount on the row.
        COALESCE(
            o.order_shop_currency,
            o.currency,
            s.shop_currency
        ) AS shop_currency,

        -- Shipping country is the right geography, but it is NULL for digital
        -- goods and POS. Cascade to billing, then the location's country.
        COALESCE(
            o.shipping_country_code,
            o.billing_country_code,
            l.location_country_code
        ) AS country
    FROM {{ ref('stg_shopify__order') }} o
    JOIN shop s USING (shopify_store)
    LEFT JOIN locations l USING (shopify_store, location_id)
    -- Only voided orders are dropped here: the money never existed. Everything
    -- else stays, including 'pending' - an authorised-but-uncaptured order
    -- (bank transfer, cash on delivery, manual payment) is a sale Shopify counts,
    -- so excluding it here would understate every report downstream. Cancelled
    -- and refunded orders also stay: their reversals arrive as their own RETURN
    -- events, so removing the order would lose the sale AND the reversal.
    -- financial_status and cancelled_at are passed through, so the analytics
    -- layer can narrow this without core having destroyed the rows.
    WHERE o.financial_status != 'voided'
),

-- Orders carrying only untitled lines are dropped by Shopify's reports: deleted
-- products, draft-order custom lines, API artifacts. Flag at order level so a
-- partial order does not half-appear. Gift-card lines count as titled.
order_line_flags AS (
    SELECT
        shopify_store,
        order_id,
        MAX(CASE WHEN is_gift_card OR product_title IS NOT NULL THEN 1 ELSE 0 END)
            AS has_product_title,
        LOGICAL_OR(requires_shipping) AS any_line_requires_shipping
    FROM {{ ref('stg_shopify__order_line') }}
    GROUP BY shopify_store, order_id
),

agreements AS (
    SELECT shopify_store, order_agreement_id, order_id, happened_at, app_handle, reason
    FROM {{ ref('stg_shopify__order_agreement') }}
),

sales AS (
    SELECT
        shopify_store, order_agreement_id, order_id, line_type, action_type, quantity,
        total_amount, total_tax, discount_before_tax, amount_ex_tax,
        presentment_total_amount, presentment_total_tax,
        presentment_discount_before_tax, presentment_amount_ex_tax,
        presentment_currency
    FROM {{ ref('stg_shopify__order_agreement_sale') }}
),

-- Earliest ORDER agreement per order, used to spot checkout-flow edits.
order_first_time AS (
    SELECT shopify_store, order_id, MIN(happened_at) AS order_created_at
    FROM agreements
    WHERE reason = 'ORDER'
    GROUP BY shopify_store, order_id
),

-- Shopify's own implied FX rate per order: presentment per 1 unit of shop money.
-- Using this beats converting shop money at your own daily rate, because Shopify
-- used its rate at checkout and yours will not match what the customer paid.
order_presentment AS (
    SELECT
        shopify_store,
        order_id,
        ANY_VALUE(presentment_currency) AS presentment_currency,
        SAFE_DIVIDE(SUM(presentment_total_amount), NULLIF(SUM(total_amount), 0))
            AS shopify_fx_rate
    FROM sales
    GROUP BY shopify_store, order_id
),

joined AS (
    SELECT
        -- Localise BEFORE truncating to a date. happened_at is UTC while Shopify
        -- reports in store-local time.
        DATE(DATETIME(a.happened_at, s.report_timezone)) AS date,
        a.shopify_store,
        a.order_id,
        a.reason,
        a.app_handle,
        o.location_id,
        o.source_name,
        o.shop_currency,
        sa.line_type,
        sa.action_type,
        sa.quantity,
        sa.total_tax,
        sa.discount_before_tax,
        sa.amount_ex_tax,
        sa.presentment_total_tax,
        sa.presentment_discount_before_tax,
        sa.presentment_amount_ex_tax,

        -- An ORDER_EDIT within 90 seconds of creation is part of the original
        -- purchase (a post-purchase upsell), not a later restatement.
        CASE
            WHEN a.reason = 'ORDER_EDIT'
             AND TIMESTAMP_DIFF(a.happened_at, oft.order_created_at, SECOND) <= 90
            THEN TRUE ELSE FALSE
        END AS is_checkout_edit
    FROM agreements a
    JOIN shop s USING (shopify_store)
    JOIN sales sa USING (shopify_store, order_agreement_id, order_id)
    JOIN orders o USING (shopify_store, order_id)
    JOIN order_line_flags olf USING (shopify_store, order_id)
    LEFT JOIN order_first_time oft USING (shopify_store, order_id)
    WHERE olf.has_product_title = 1
),

typed AS (
    SELECT
        *,
        CASE
            WHEN action_type IN ('ORDER', 'UPDATE') THEN 'SALE'
            WHEN action_type = 'RETURN'             THEN 'RETURN'
        END AS report_row_type
    FROM joined
    WHERE action_type IN ('ORDER', 'UPDATE', 'RETURN')
),

-- Shopify lumps cancellations, returns and refunds together; your business does
-- not. restock_type on the refunded lines tells them apart. Return rate measured
-- on RETURN alone is a product-quality signal; on all three it is noise.
refunds AS (
    SELECT
        r.shopify_store,
        r.refund_id,
        r.order_id,
        DATE(DATETIME(r.refund_created_at, s.report_timezone)) AS date
    FROM {{ ref('stg_shopify__order_refund') }} r
    JOIN shop s USING (shopify_store)
),

refund_detail AS (
    SELECT
        r.shopify_store,
        r.date,
        r.order_id,
        olr.restock_type,
        olr.location_id,
        SUM(olr.quantity) AS qty
    FROM {{ ref('stg_shopify__order_line_refund') }} olr
    JOIN refunds r USING (shopify_store, refund_id)
    GROUP BY 1, 2, 3, 4, 5
),

reversal_type AS (
    SELECT
        shopify_store,
        date,
        order_id,
        CASE
            WHEN restock_type = 'cancel' THEN 'CANCELLATION'  -- never shipped
            WHEN restock_type = 'return' THEN 'RETURN'        -- came back, restocked
            ELSE 'REFUND'                                     -- money back, no restock
        END AS reversal_type
    FROM refund_detail
    -- The dominant restock type wins when one refund mixes them.
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY shopify_store, date, order_id
        ORDER BY qty DESC, restock_type
    ) = 1
),

-- Carry the last known refund location forward so a multi-day return sequence
-- does not fragment across locations.
refund_location AS (
    SELECT
        shopify_store,
        date,
        order_id,
        LAST_VALUE(location_id IGNORE NULLS) OVER (
            PARTITION BY shopify_store, order_id ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS refund_location_id
    FROM (
        SELECT shopify_store, date, order_id, MAX(location_id) AS location_id
        FROM refund_detail
        GROUP BY 1, 2, 3
    )
),

agg AS (
    SELECT
        date,
        shopify_store,
        order_id,
        location_id,
        source_name,
        shop_currency,
        report_row_type,

        -- MAX not SUM: one order is one order however many lines it has.
        -- Excluding ORDER_EDIT stops an edited order counting again on the edit date.
        MAX(CASE
                WHEN report_row_type = 'SALE' AND line_type = 'PRODUCT'
                 AND action_type = 'ORDER' AND reason NOT IN ('RETURN', 'ORDER_EDIT')
                THEN 1 ELSE 0
            END) AS orders,

        -- 1. Net unit movement: sales minus returns.
        SUM(CASE
                WHEN report_row_type = 'SALE'   AND line_type IN ('PRODUCT', 'GIFT_CARD')  THEN quantity
                WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT') THEN quantity
                ELSE 0
            END) AS quantity,

        -- 2. Strict units ordered: no returns, no edits. Matches the admin UI.
        SUM(CASE
                WHEN report_row_type = 'SALE' AND line_type = 'PRODUCT'
                 AND action_type = 'ORDER' AND reason NOT IN ('RETURN', 'ORDER_EDIT')
                THEN quantity ELSE 0
            END) AS quantity_ordered_shopify_compat,

        -- 3. Keeps checkout-flow edits, drops post-order edits. Matches Shopify's
        --    CSV export, which differs from the UI.
        SUM(CASE
                WHEN report_row_type = 'SALE' AND line_type IN ('PRODUCT', 'GIFT_CARD')
                 AND action_type = 'ORDER' AND reason != 'RETURN'
                 AND (reason != 'ORDER_EDIT' OR is_checkout_edit)
                THEN quantity ELSE 0
            END) AS quantity_ordered_shopify_export_parity,

        -- RETURN rows carry negative amounts, so they reduce net sales on their
        -- own. ADJUSTMENT lines are refund value Shopify cannot tie to a product
        -- line (partial refunds, goodwill credits) - including them is what makes
        -- returns tie out.
        SUM(CASE
                WHEN report_row_type = 'SALE'   AND line_type = 'PRODUCT'                  THEN amount_ex_tax
                WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT') THEN amount_ex_tax
                ELSE 0
            END) AS net_sales,

        -- Same, excluding POST-ORDER edits: reconciles to the admin UI.
        SUM(CASE
                WHEN report_row_type = 'SALE' AND line_type = 'PRODUCT'
                 AND (reason != 'ORDER_EDIT' OR is_checkout_edit)                          THEN amount_ex_tax
                WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT') THEN amount_ex_tax
                ELSE 0
            END) AS net_sales_shopify_parity,

        -- GREATEST guards negative discounts, which appear on some edit and
        -- return events and would otherwise inflate the total.
        (-1) * SUM(CASE
                       WHEN report_row_type = 'SALE' AND line_type = 'PRODUCT'
                       THEN GREATEST(discount_before_tax, 0) ELSE 0
                   END) AS discounts,

        SUM(CASE WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT')
                 THEN amount_ex_tax ELSE 0 END) AS returns,
        SUM(CASE WHEN report_row_type = 'RETURN' AND line_type = 'ADJUSTMENT'
                 THEN amount_ex_tax ELSE 0 END) AS return_adjustments,

        -- No row_type filter: shipping and fees occur on sales AND refunds, and a
        -- refunded shipping charge should reduce the total.
        SUM(CASE WHEN line_type = 'SHIPPING' THEN amount_ex_tax ELSE 0 END) AS shipping_charges,
        SUM(CASE WHEN line_type = 'DUTY'     THEN amount_ex_tax ELSE 0 END) AS duties,
        SUM(CASE WHEN line_type = 'FEE'      THEN amount_ex_tax ELSE 0 END) AS return_fees,
        CAST(0 AS NUMERIC)                                                  AS additional_fees,
        SUM(total_tax)                                                      AS taxes,

        -- Returns detail block.
        SUM(CASE WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT')
                 THEN amount_ex_tax ELSE 0 END) AS sales_reversals,
        (-1) * SUM(CASE WHEN report_row_type = 'RETURN' AND line_type = 'PRODUCT'
                        THEN discount_before_tax ELSE 0 END) AS discount_reversals,
        SUM(CASE WHEN report_row_type = 'RETURN' THEN total_tax ELSE 0 END) AS tax_reversals,
        SUM(CASE WHEN report_row_type = 'RETURN' AND line_type = 'SHIPPING'
                 THEN amount_ex_tax ELSE 0 END) AS shipping_reversals,
        SUM(CASE WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT')
                 THEN quantity ELSE 0 END) AS reversed_quantity,

        -- Gift cards are deferred revenue, kept out of the sales equation.
        SUM(CASE WHEN line_type = 'GIFT_CARD'
                 THEN amount_ex_tax + GREATEST(discount_before_tax, 0) ELSE 0 END) AS gift_card_gross_sales,
        SUM(CASE WHEN line_type = 'GIFT_CARD' THEN amount_ex_tax ELSE 0 END)       AS gift_card_net_sales,
        (-1) * SUM(CASE WHEN line_type = 'GIFT_CARD'
                        THEN GREATEST(discount_before_tax, 0) ELSE 0 END)          AS gift_card_discounts,
        SUM(CASE WHEN line_type = 'GIFT_CARD' THEN total_tax ELSE 0 END)           AS gift_card_taxes,

        -- Presentment money: what the customer actually paid, before any
        -- conversion of ours.
        SUM(CASE
                WHEN report_row_type = 'SALE'   AND line_type = 'PRODUCT'                  THEN presentment_amount_ex_tax
                WHEN report_row_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT') THEN presentment_amount_ex_tax
                ELSE 0
            END) AS presentment_net_sales,
        SUM(presentment_total_tax) AS presentment_taxes
    FROM typed
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)

SELECT
    a.date,
    a.shopify_store,
    a.order_id,
    o.order_name,
    a.report_row_type,
    a.shop_currency,
    o.country,
    a.source_name,

    -- The order's own location, straight from Shopify. NULL means Shopify
    -- recorded no location - usually an online-store order - and is left NULL
    -- rather than labelled, because "no physical location" is not the same claim
    -- as "online". Identical expression in product_sales_over_time, so the two
    -- models reconcile on this dimension.
    own_loc.location_name AS location_name,

    -- Where a refund was processed, which is often NOT where the order was
    -- placed: a POS sale returned through the web admin has a store
    -- location_name and no refund location. Kept as its own column rather than
    -- coalesced into location_name - they are two different facts, and merging
    -- them makes it impossible to ask either question. NULL on SALE rows.
    rf_loc.location_name AS refund_location_name,

    -- Shopify's own channel value, not an interpretation of it: 'web' for the
    -- online store, 'pos' for retail, 'shopify_draft_order' for manual orders,
    -- otherwise the handle of the app or marketplace that created the order.
    -- Split retail from online with this, or with location_name IS NOT NULL.
    LOWER(a.source_name) AS sales_channel,

    -- An order of only digital goods never gets a fulfillment status, which reads
    -- as "unfulfilled" in every dashboard and panics ops. Distinguish it.
    CASE
        WHEN o.fulfillment_status IS NULL AND olf.any_line_requires_shipping = FALSE
        THEN 'fulfillment_not_required'
        ELSE o.fulfillment_status
    END AS fulfillment_status,

    o.financial_status,
    rt.reversal_type,
    o.cancelled_at IS NOT NULL AS is_cancelled,

    a.orders,

    -- Exactly ONE row per order, on its first SALE day. Summing over any window
    -- gives "orders placed", the AOV denominator Shopify uses. Counts edit-only
    -- orders with no ORDER row, ignores return-only orders, and never
    -- double-counts across locations or days.
    CASE
        WHEN a.report_row_type = 'SALE'
         AND ROW_NUMBER() OVER (
                 PARTITION BY a.shopify_store, a.order_id
                 ORDER BY
                     CASE WHEN a.report_row_type = 'SALE' THEN 0 ELSE 1 END,
                     a.date ASC, a.location_id ASC, a.source_name ASC
             ) = 1
        THEN 1 ELSE 0
    END AS is_order_placed,

    a.quantity,
    a.quantity_ordered_shopify_compat,
    a.quantity_ordered_shopify_export_parity,

    -- discounts and returns are stored negative, so subtracting adds them back.
    ROUND(a.net_sales - a.discounts - a.returns, 2) AS gross_sales,
    ROUND(a.discounts, 2)                          AS discounts,
    ROUND(a.returns, 2)                            AS returns,
    ROUND(a.return_adjustments, 2)                 AS return_adjustments,
    ROUND(a.net_sales, 2)                          AS net_sales,
    ROUND(a.net_sales_shopify_parity, 2)           AS net_sales_shopify_parity,

    ROUND(a.shipping_charges, 2)                   AS shipping_charges,
    ROUND(a.duties, 2)                             AS duties,
    ROUND(a.return_fees, 2)                        AS return_fees,
    ROUND(a.additional_fees, 2)                    AS additional_fees,
    ROUND(a.taxes, 2)                              AS taxes,

    -- Matches the Shopify admin UI.
    ROUND(a.net_sales + a.shipping_charges + a.duties
          + a.return_fees + a.additional_fees + a.taxes, 2) AS total_shopify_sales,
    -- Excludes tax and duties (pass-through money); what finance usually wants.
    ROUND(a.net_sales + a.shipping_charges
          + a.return_fees + a.additional_fees, 2)           AS total_sales,

    ROUND(a.sales_reversals, 2)                             AS net_sales_reversals,
    ROUND(a.sales_reversals - a.discount_reversals, 2)      AS gross_sales_reversals,
    ROUND(a.sales_reversals + a.tax_reversals
          + a.shipping_reversals + a.return_fees, 2)        AS total_sales_reversals,
    ROUND(a.discount_reversals, 2)                          AS discount_reversals,
    ROUND(a.tax_reversals, 2)                               AS tax_reversals,
    ROUND(a.shipping_reversals, 2)                          AS shipping_reversals,
    a.reversed_quantity,

    ROUND(a.gift_card_gross_sales, 2) AS gift_card_gross_sales,
    ROUND(a.gift_card_net_sales, 2)   AS gift_card_net_sales,
    ROUND(a.gift_card_discounts, 2)   AS gift_card_discounts,
    ROUND(a.gift_card_taxes, 2)       AS gift_card_taxes,
    ROUND(a.taxes - a.gift_card_taxes, 2) AS taxes_excluding_gift_cards,

    -- What the customer actually paid, and the rate Shopify used at checkout.
    op.presentment_currency,
    ROUND(a.presentment_net_sales, 2) AS presentment_net_sales,
    ROUND(a.presentment_taxes, 2)     AS presentment_taxes,
    op.shopify_fx_rate
FROM agg a
JOIN orders o USING (shopify_store, order_id)
JOIN order_line_flags olf USING (shopify_store, order_id)
LEFT JOIN order_presentment op USING (shopify_store, order_id)
LEFT JOIN reversal_type rt       ON  rt.shopify_store = a.shopify_store
                                 AND rt.order_id      = a.order_id
                                 AND rt.date          = a.date
LEFT JOIN refund_location rf     ON  rf.shopify_store = a.shopify_store
                                 AND rf.order_id      = a.order_id
                                 AND rf.date          = a.date
LEFT JOIN locations rf_loc       ON  rf_loc.shopify_store = a.shopify_store
                                 AND rf_loc.location_id   = rf.refund_location_id
LEFT JOIN locations own_loc      ON  own_loc.shopify_store = a.shopify_store
                                 AND own_loc.location_id   = a.location_id
ORDER BY a.date, a.shopify_store, a.order_id, a.report_row_type
