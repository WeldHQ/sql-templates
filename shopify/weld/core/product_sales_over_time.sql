-- shopify_product_sales_over_time
--
-- The sales report at line grain: day x store x order x line. This is the model
-- merchandising lives in, and the one that makes SKU-level margin possible.
--
-- It reconciles to sales_over_time. That is the whole point, and it is why the
-- non-product rows are here: shipping, fees, gift cards and unattributable refund
-- adjustments are emitted as rows with a NULL sku. Drop them and this model sits
-- below the sales report by exactly the value of shipping and fees, and someone
-- spends a week finding out why.
--
-- The hard part is attribution. An agreement records that money moved on an order,
-- not always which line it belongs to, so product money is distributed across the
-- order's lines by weight - units follow quantity share, money follows revenue
-- share. Using one weight for both distorts mixed-price baskets.
--
-- Returns arrive from two places: agreement RETURN events and order_line_refund
-- rows. Same money, two sources. Naively unioning both doubles returns, so the
-- refund rows attribute per line and only the unexplained residual is spread.
--
-- Depends on: staging.shopify.{order, order_line, order_agreement,
--             order_agreement_sale, order_refund, order_line_refund, location,
--             shop} and core.shopify.sku_cost_per_day

WITH shop AS (
    SELECT
        shopify_store,
        ANY_VALUE(currency)                       AS shop_currency,
        COALESCE(ANY_VALUE(iana_timezone), 'UTC') AS report_timezone
    FROM {{staging.shopify.shop}}
    GROUP BY shopify_store
),

locations AS (
    SELECT shopify_store, location_id, location_name, location_country_code
    FROM {{staging.shopify.location}}
),

orders AS (
    SELECT
        o.shopify_store,
        o.order_id,
        o.order_name,
        o.location_id,
        o.source_name,
        o.financial_status,
        o.cancelled_at,
        DATE(DATETIME(o.processed_at, s.report_timezone)) AS order_created_day,
        -- No presentment-currency fallback and no default code: presentment is
        -- the buyer's currency, and a guessed code mislabels every amount.
        COALESCE(o.order_shop_currency, o.currency, s.shop_currency) AS shop_currency,
        -- Shipping country is the right geography but is NULL for digital goods
        -- and POS, so cascade to billing, then the location's country.
        COALESCE(o.shipping_country_code, o.billing_country_code, l.location_country_code) AS country,
        -- The order's own location, straight from Shopify, NULL when there is
        -- none. Identical expression in sales_over_time so the two models
        -- reconcile on this dimension - they previously disagreed, which meant
        -- a per-location comparison between them could never tie.
        l.location_name AS location_name
    FROM {{staging.shopify.order}} o
    JOIN shop s USING (shopify_store)
    LEFT JOIN locations l USING (shopify_store, location_id)
    -- Voided only - see sales_over_time. Keeping 'pending' matters for parity:
    -- if the two models filter orders differently they cannot reconcile.
    WHERE o.financial_status != 'voided'
),

-- Untitled lines are dropped by Shopify's product reports: deleted products,
-- draft-order custom lines, API artifacts.
order_lines AS (
    SELECT
        shopify_store, order_id, line_id, product_id, variant_id,
        product_title, variant_title, sku, vendor,
        CAST(quantity AS NUMERIC) AS ordered_quantity,
        unit_price,
        discounts                 AS line_discount,
        gross_sales               AS line_gross_sales,
        gross_sales - discounts   AS line_net_sales
    FROM {{staging.shopify.order_line}}
    WHERE NOT is_gift_card
      AND product_title IS NOT NULL
),

-- Two weights, deliberately: money follows revenue share, units follow quantity
-- share. The ELSE branch splits evenly for fully discounted orders, where every
-- line is zero and a share would be undefined.
line_weights AS (
    SELECT
        ol.*,
        CASE
            WHEN SUM(GREATEST(ol.ordered_quantity, 0))
                   OVER (PARTITION BY ol.shopify_store, ol.order_id) > 0
            THEN SAFE_DIVIDE(GREATEST(ol.ordered_quantity, 0),
                             SUM(GREATEST(ol.ordered_quantity, 0))
                               OVER (PARTITION BY ol.shopify_store, ol.order_id))
            ELSE SAFE_DIVIDE(1, COUNT(*) OVER (PARTITION BY ol.shopify_store, ol.order_id))
        END AS quantity_weight,
        CASE
            WHEN SUM(GREATEST(ol.line_net_sales, 0))
                   OVER (PARTITION BY ol.shopify_store, ol.order_id) > 0
            THEN SAFE_DIVIDE(GREATEST(ol.line_net_sales, 0),
                             SUM(GREATEST(ol.line_net_sales, 0))
                               OVER (PARTITION BY ol.shopify_store, ol.order_id))
            ELSE SAFE_DIVIDE(1, COUNT(*) OVER (PARTITION BY ol.shopify_store, ol.order_id))
        END AS revenue_weight
    FROM order_lines ol
),

agreements AS (
    SELECT shopify_store, order_agreement_id, order_id, happened_at, reason
    FROM {{staging.shopify.order_agreement}}
),

sales AS (
    SELECT
        shopify_store, order_agreement_id, order_id, line_type, action_type,
        CAST(quantity AS NUMERIC) AS quantity,
        total_tax, discount_before_tax, amount_ex_tax
    FROM {{staging.shopify.order_agreement_sale}}
),

events AS (
    SELECT
        DATE(DATETIME(a.happened_at, s.report_timezone)) AS date,
        a.shopify_store, a.order_id, a.reason,
        sa.line_type, sa.action_type, sa.quantity,
        sa.total_tax, sa.discount_before_tax, sa.amount_ex_tax
    FROM agreements a
    JOIN shop s USING (shopify_store)
    JOIN sales sa USING (shopify_store, order_agreement_id, order_id)
),

-- ---------------------------------------------------------------- product sales
sale_order_day AS (
    SELECT
        date, shopify_store, order_id,
        SUM(quantity) AS sale_quantity,
        SUM(CASE WHEN action_type = 'ORDER'
                  AND reason NOT IN ('RETURN', 'ORDER_EDIT') THEN quantity ELSE 0 END)
            AS quantity_ordered_shopify_compat,
        SUM(CASE WHEN action_type = 'ORDER'
                  AND reason != 'RETURN' THEN quantity ELSE 0 END)
            AS quantity_ordered_shopify_export_parity,
        SUM(amount_ex_tax)                          AS net_sales,
        (-1) * SUM(GREATEST(discount_before_tax, 0)) AS discounts,
        SUM(total_tax)                              AS taxes
    FROM events
    WHERE line_type = 'PRODUCT' AND action_type IN ('ORDER', 'UPDATE')
    GROUP BY 1, 2, 3
),

sale_line_events AS (
    SELECT
        d.date, o.shopify_store, o.order_id, o.order_name, o.financial_status,
        o.cancelled_at, o.location_id, o.source_name, o.shop_currency, o.country,
        o.location_name, 'SALE' AS report_row_type,
        lw.line_id, lw.product_id, lw.variant_id, lw.product_title, lw.variant_title,
        lw.sku, lw.vendor, lw.unit_price,
        d.sale_quantity * lw.quantity_weight                          AS quantity,
        d.quantity_ordered_shopify_compat * lw.quantity_weight        AS quantity_ordered_shopify_compat,
        d.quantity_ordered_shopify_export_parity * lw.quantity_weight AS quantity_ordered_shopify_export_parity,
        -- Fractional on purpose: each line carries its share of one order, so the
        -- lines still sum to exactly 1.0 per order-day and the two reports tie.
        CASE WHEN d.date = o.order_created_day THEN lw.revenue_weight ELSE 0 END AS orders,
        (d.net_sales - d.discounts) * lw.revenue_weight AS gross_sales,
        d.discounts * lw.revenue_weight                 AS discounts,
        CAST(0 AS NUMERIC)                              AS returns,
        d.net_sales * lw.revenue_weight                 AS net_sales,
        CAST(0 AS NUMERIC)                              AS shipping_charges,
        CAST(0 AS NUMERIC)                              AS duties,
        CAST(0 AS NUMERIC)                              AS additional_fees,
        CAST(0 AS NUMERIC)                              AS return_fees,
        d.taxes * lw.revenue_weight                     AS taxes,
        CAST(0 AS NUMERIC)                              AS sales_reversals,
        CAST(0 AS NUMERIC)                              AS discount_reversals,
        CAST(0 AS NUMERIC)                              AS tax_reversals,
        CAST(0 AS NUMERIC)                              AS shipping_reversals,
        CAST(0 AS NUMERIC)                              AS reversed_quantity,
        CAST(0 AS NUMERIC)                              AS gift_card_gross_sales,
        CAST(0 AS NUMERIC)                              AS gift_card_net_sales,
        CAST(0 AS NUMERIC)                              AS gift_card_discounts,
        CAST(0 AS NUMERIC)                              AS gift_card_taxes
    FROM line_weights lw
    JOIN sale_order_day d USING (shopify_store, order_id)
    JOIN orders o         USING (shopify_store, order_id)
),

-- ---------------------------------------------------------------------- returns
refunds AS (
    SELECT
        r.shopify_store, r.refund_id, r.order_id,
        DATE(DATETIME(r.refund_created_at, s.report_timezone)) AS date
    FROM {{staging.shopify.order_refund}} r
    JOIN shop s USING (shopify_store)
),

-- What the agreements say the return was worth, per order-day.
return_order_day AS (
    SELECT
        date, shopify_store, order_id,
        SUM(quantity)                                AS return_quantity,
        SUM(amount_ex_tax)                           AS return_net_sales,
        (-1) * SUM(discount_before_tax)              AS return_discount_reversals,
        SUM(total_tax)                               AS return_taxes
    FROM events
    WHERE action_type = 'RETURN' AND line_type IN ('PRODUCT', 'ADJUSTMENT')
    GROUP BY 1, 2, 3
),

-- What the per-line refund rows already account for.
refund_line_totals AS (
    SELECT
        r.date, r.shopify_store, r.order_id, olr.order_line_id AS line_id,
        SUM(CAST(olr.quantity AS NUMERIC)) AS refund_quantity
    FROM {{staging.shopify.order_line_refund}} olr
    JOIN refunds r USING (shopify_store, refund_id)
    GROUP BY 1, 2, 3, 4
),

refund_order_day AS (
    SELECT date, shopify_store, order_id, SUM(refund_quantity) AS refund_quantity
    FROM refund_line_totals
    GROUP BY 1, 2, 3
),

-- Returns land per line where the refund rows say so.
return_line_events AS (
    SELECT
        rlt.date, o.shopify_store, o.order_id, o.order_name, o.financial_status,
        o.cancelled_at, o.location_id, o.source_name, o.shop_currency, o.country,
        o.location_name, 'RETURN' AS report_row_type,
        lw.line_id, lw.product_id, lw.variant_id, lw.product_title, lw.variant_title,
        lw.sku, lw.vendor, lw.unit_price,
        (-1) * rlt.refund_quantity                              AS quantity,
        CAST(0 AS NUMERIC)                                      AS quantity_ordered_shopify_compat,
        CAST(0 AS NUMERIC)                                      AS quantity_ordered_shopify_export_parity,
        CAST(0 AS NUMERIC)                                      AS orders,
        CAST(0 AS NUMERIC)                                      AS gross_sales,
        CAST(0 AS NUMERIC)                                      AS discounts,
        (-1) * rlt.refund_quantity * lw.unit_price              AS returns,
        (-1) * rlt.refund_quantity * lw.unit_price              AS net_sales,
        CAST(0 AS NUMERIC)                                      AS shipping_charges,
        CAST(0 AS NUMERIC)                                      AS duties,
        CAST(0 AS NUMERIC)                                      AS additional_fees,
        CAST(0 AS NUMERIC)                                      AS return_fees,
        CAST(0 AS NUMERIC)                                      AS taxes,
        (-1) * rlt.refund_quantity * lw.unit_price              AS sales_reversals,
        CAST(0 AS NUMERIC)                                      AS discount_reversals,
        CAST(0 AS NUMERIC)                                      AS tax_reversals,
        CAST(0 AS NUMERIC)                                      AS shipping_reversals,
        (-1) * rlt.refund_quantity                              AS reversed_quantity,
        CAST(0 AS NUMERIC)                                      AS gift_card_gross_sales,
        CAST(0 AS NUMERIC)                                      AS gift_card_net_sales,
        CAST(0 AS NUMERIC)                                      AS gift_card_discounts,
        CAST(0 AS NUMERIC)                                      AS gift_card_taxes
    FROM refund_line_totals rlt
    JOIN line_weights lw USING (shopify_store, order_id, line_id)
    JOIN orders o        USING (shopify_store, order_id)
),

-- Whatever the agreements say was returned but the refund rows did not explain -
-- partial refunds, goodwill credits - spread across the order's lines. Without
-- this the two reports disagree; with it counted twice, returns double.
return_residual AS (
    SELECT
        rod.date, rod.shopify_store, rod.order_id,
        rod.return_quantity + COALESCE(rfd.refund_quantity, 0) AS residual_quantity,
        rod.return_net_sales,
        rod.return_discount_reversals,
        rod.return_taxes
    FROM return_order_day rod
    LEFT JOIN refund_order_day rfd USING (date, shopify_store, order_id)
),

return_adjustment_events AS (
    SELECT
        rr.date, o.shopify_store, o.order_id, o.order_name, o.financial_status,
        o.cancelled_at, o.location_id, o.source_name, o.shop_currency, o.country,
        o.location_name, 'RETURN' AS report_row_type,
        CAST(NULL AS INT64)  AS line_id,
        CAST(NULL AS INT64)  AS product_id,
        CAST(NULL AS INT64)  AS variant_id,
        CAST(NULL AS STRING) AS product_title,
        CAST(NULL AS STRING) AS variant_title,
        CAST(NULL AS STRING) AS sku,
        CAST(NULL AS STRING) AS vendor,
        CAST(NULL AS NUMERIC) AS unit_price,
        rr.residual_quantity              AS quantity,
        CAST(0 AS NUMERIC)                AS quantity_ordered_shopify_compat,
        CAST(0 AS NUMERIC)                AS quantity_ordered_shopify_export_parity,
        CAST(0 AS NUMERIC)                AS orders,
        CAST(0 AS NUMERIC)                AS gross_sales,
        CAST(0 AS NUMERIC)                AS discounts,
        rr.return_net_sales               AS returns,
        rr.return_net_sales               AS net_sales,
        CAST(0 AS NUMERIC)                AS shipping_charges,
        CAST(0 AS NUMERIC)                AS duties,
        CAST(0 AS NUMERIC)                AS additional_fees,
        CAST(0 AS NUMERIC)                AS return_fees,
        rr.return_taxes                   AS taxes,
        rr.return_net_sales               AS sales_reversals,
        rr.return_discount_reversals      AS discount_reversals,
        rr.return_taxes                   AS tax_reversals,
        CAST(0 AS NUMERIC)                AS shipping_reversals,
        rr.residual_quantity              AS reversed_quantity,
        CAST(0 AS NUMERIC)                AS gift_card_gross_sales,
        CAST(0 AS NUMERIC)                AS gift_card_net_sales,
        CAST(0 AS NUMERIC)                AS gift_card_discounts,
        CAST(0 AS NUMERIC)                AS gift_card_taxes
    FROM return_residual rr
    JOIN orders o USING (shopify_store, order_id)
    -- Floating-point residue would otherwise produce thousands of near-zero rows.
    WHERE ABS(rr.return_net_sales) > 0.0001
       OR ABS(rr.return_discount_reversals) > 0.0001
       OR ABS(rr.residual_quantity) > 0.0001
),

-- ------------------------------------------------- non-product money, NULL sku
-- These belong to the order, not to any line. Shopify's own product exports show
-- them with an empty product column, and they are what makes this model tie out
-- against sales_over_time.
non_product_day AS (
    SELECT
        date, shopify_store, order_id,
        SUM(CASE WHEN line_type = 'SHIPPING' THEN amount_ex_tax ELSE 0 END) AS shipping_charges,
        SUM(CASE WHEN line_type = 'SHIPPING' AND action_type = 'RETURN'
                 THEN amount_ex_tax ELSE 0 END)                             AS shipping_reversals,
        SUM(CASE WHEN line_type = 'DUTY' THEN amount_ex_tax ELSE 0 END)     AS duties,
        SUM(CASE WHEN line_type = 'FEE'  THEN amount_ex_tax ELSE 0 END)     AS return_fees,
        SUM(CASE WHEN line_type IN ('SHIPPING', 'DUTY', 'FEE')
                 THEN total_tax ELSE 0 END)                                 AS taxes,
        SUM(CASE WHEN line_type = 'GIFT_CARD'
                 THEN amount_ex_tax + GREATEST(discount_before_tax, 0) ELSE 0 END) AS gift_card_gross_sales,
        SUM(CASE WHEN line_type = 'GIFT_CARD' THEN amount_ex_tax ELSE 0 END)       AS gift_card_net_sales,
        (-1) * SUM(CASE WHEN line_type = 'GIFT_CARD'
                        THEN GREATEST(discount_before_tax, 0) ELSE 0 END)          AS gift_card_discounts,
        SUM(CASE WHEN line_type = 'GIFT_CARD' THEN total_tax ELSE 0 END)           AS gift_card_taxes
    FROM events
    WHERE line_type IN ('SHIPPING', 'DUTY', 'FEE', 'GIFT_CARD')
    GROUP BY 1, 2, 3
),

non_product_line_events AS (
    SELECT
        d.date, o.shopify_store, o.order_id, o.order_name, o.financial_status,
        o.cancelled_at, o.location_id, o.source_name, o.shop_currency, o.country,
        o.location_name, 'SALE' AS report_row_type,
        CAST(NULL AS INT64)   AS line_id,
        CAST(NULL AS INT64)   AS product_id,
        CAST(NULL AS INT64)   AS variant_id,
        CAST(NULL AS STRING)  AS product_title,
        CAST(NULL AS STRING)  AS variant_title,
        CAST(NULL AS STRING)  AS sku,
        CAST(NULL AS STRING)  AS vendor,
        CAST(NULL AS NUMERIC) AS unit_price,
        CAST(0 AS NUMERIC)    AS quantity,
        CAST(0 AS NUMERIC)    AS quantity_ordered_shopify_compat,
        CAST(0 AS NUMERIC)    AS quantity_ordered_shopify_export_parity,
        CAST(0 AS NUMERIC)    AS orders,
        CAST(0 AS NUMERIC)    AS gross_sales,
        CAST(0 AS NUMERIC)    AS discounts,
        CAST(0 AS NUMERIC)    AS returns,
        CAST(0 AS NUMERIC)    AS net_sales,
        d.shipping_charges    AS shipping_charges,
        d.duties              AS duties,
        CAST(0 AS NUMERIC)    AS additional_fees,
        d.return_fees         AS return_fees,
        d.taxes               AS taxes,
        CAST(0 AS NUMERIC)    AS sales_reversals,
        CAST(0 AS NUMERIC)    AS discount_reversals,
        CAST(0 AS NUMERIC)    AS tax_reversals,
        d.shipping_reversals  AS shipping_reversals,
        CAST(0 AS NUMERIC)    AS reversed_quantity,
        d.gift_card_gross_sales,
        d.gift_card_net_sales,
        d.gift_card_discounts,
        d.gift_card_taxes
    FROM non_product_day d
    JOIN orders o USING (shopify_store, order_id)
),

-- UNION ALL matches positionally, not by name: every branch must emit the same
-- columns in the same order. Verbose, but adding an event type is copy-paste
-- plus one union line.
line_events AS (
    SELECT * FROM sale_line_events
    UNION ALL SELECT * FROM return_line_events
    UNION ALL SELECT * FROM return_adjustment_events
    UNION ALL SELECT * FROM non_product_line_events
),

final_base AS (
    SELECT
        date, shopify_store, order_id, order_name, financial_status, cancelled_at,
        location_id, source_name, shop_currency, country, location_name,
        report_row_type, line_id, product_id, variant_id, product_title,
        variant_title, sku, vendor,
        MAX(unit_price)                                     AS unit_price,
        SUM(quantity)                                       AS quantity,
        SUM(quantity_ordered_shopify_compat)                AS quantity_ordered_shopify_compat,
        SUM(quantity_ordered_shopify_export_parity)         AS quantity_ordered_shopify_export_parity,
        SUM(orders)                                         AS orders,
        SUM(gross_sales)                                    AS gross_sales,
        SUM(discounts)                                      AS discounts,
        SUM(returns)                                        AS returns,
        SUM(net_sales)                                      AS net_sales,
        SUM(shipping_charges)                               AS shipping_charges,
        SUM(duties)                                         AS duties,
        SUM(additional_fees)                                AS additional_fees,
        SUM(return_fees)                                    AS return_fees,
        SUM(taxes)                                          AS taxes,
        SUM(sales_reversals)                                AS sales_reversals,
        SUM(discount_reversals)                             AS discount_reversals,
        SUM(tax_reversals)                                  AS tax_reversals,
        SUM(shipping_reversals)                             AS shipping_reversals,
        SUM(reversed_quantity)                              AS reversed_quantity,
        SUM(gift_card_gross_sales)                          AS gift_card_gross_sales,
        SUM(gift_card_net_sales)                            AS gift_card_net_sales,
        SUM(gift_card_discounts)                            AS gift_card_discounts,
        SUM(gift_card_taxes)                                AS gift_card_taxes
    FROM line_events
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
)

SELECT
    fb.date,
    fb.shopify_store,
    fb.order_id,
    fb.order_name,
    fb.report_row_type,
    fb.financial_status,
    fb.cancelled_at IS NOT NULL AS is_cancelled,
    fb.location_name,
    fb.country,
    fb.source_name,
    LOWER(fb.source_name) AS sales_channel,
    fb.shop_currency,

    fb.line_id,
    fb.product_id,
    fb.variant_id,
    fb.product_title,
    fb.variant_title,
    fb.sku,
    fb.vendor,
    fb.unit_price,

    fb.orders,
    fb.quantity,
    fb.quantity_ordered_shopify_compat,
    fb.quantity_ordered_shopify_export_parity,

    ROUND(fb.gross_sales, 2)      AS gross_sales,
    ROUND(fb.discounts, 2)        AS discounts,
    ROUND(fb.returns, 2)          AS returns,
    ROUND(fb.net_sales, 2)        AS net_sales,
    ROUND(fb.shipping_charges, 2) AS shipping_charges,
    ROUND(fb.duties, 2)           AS duties,
    ROUND(fb.additional_fees, 2)  AS additional_fees,
    ROUND(fb.return_fees, 2)      AS return_fees,
    ROUND(fb.taxes, 2)            AS taxes,
    ROUND(fb.net_sales + fb.shipping_charges + fb.duties
          + fb.return_fees + fb.additional_fees + fb.taxes, 2) AS total_shopify_sales,
    ROUND(fb.net_sales + fb.shipping_charges
          + fb.return_fees + fb.additional_fees, 2)            AS total_sales,

    ROUND(fb.sales_reversals, 2)                            AS net_sales_reversals,
    ROUND(fb.sales_reversals - fb.discount_reversals, 2)    AS gross_sales_reversals,
    ROUND(fb.sales_reversals + fb.tax_reversals
          + fb.shipping_reversals + fb.return_fees, 2)      AS total_sales_reversals,
    ROUND(fb.discount_reversals, 2)                         AS discount_reversals,
    ROUND(fb.tax_reversals, 2)                              AS tax_reversals,
    ROUND(fb.shipping_reversals, 2)                         AS shipping_reversals,
    fb.reversed_quantity,

    ROUND(fb.gift_card_gross_sales, 2)      AS gift_card_gross_sales,
    ROUND(fb.gift_card_net_sales, 2)        AS gift_card_net_sales,
    ROUND(fb.gift_card_discounts, 2)        AS gift_card_discounts,
    ROUND(fb.gift_card_taxes, 2)            AS gift_card_taxes,
    ROUND(fb.taxes - fb.gift_card_taxes, 2) AS taxes_excluding_gift_cards,

    -- Point-in-time cost, so a January order is valued at January's cost. NULL
    -- rather than 0 where cost is unknown: a zero cost reads as 100% margin and
    -- ends up in a board deck, a NULL shows up as the coverage gap it is.
    scd.standard_cost,
    ROUND(fb.quantity * scd.standard_cost, 2) AS cogs,
    ROUND(fb.net_sales - (fb.quantity * scd.standard_cost), 2) AS gross_profit
FROM final_base fb
LEFT JOIN {{core.shopify.sku_cost_per_day}} scd
    USING (date, shopify_store, sku)
ORDER BY fb.date, fb.shopify_store, fb.order_id, fb.line_id
