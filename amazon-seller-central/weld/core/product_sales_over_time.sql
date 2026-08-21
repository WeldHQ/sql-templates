-- amazon_seller_product_sales_over_time - the sales equation at line grain, event
-- based, so returns land on the day they happened.
--
-- Grain: day x seller x marketplace x ASIN x SKU x row type. Currency: the order's.
-- Depends on: staging.amazon_seller.orders, .returns, .fba_returns, .listings
--
-- THIS IS THE MODEL THAT MAKES AMAZON DATA BEHAVE. Everything else in the connector
-- is a current-state report; this one is an event log.
--
-- The mistake it exists to prevent: `SUM(item_price)` off the order report, grouped
-- by purchase_date. It looks right, it ties to Amazon for a fresh month, and then
-- it drifts - because a refund issued today reduces the day the order was PLACED.
-- Last quarter's revenue changes after you have reported it, and nobody can explain
-- why the same query returns two different answers a week apart.
--
-- The fix is to stop treating a sale and its reversal as one fact. A row here is a
-- financial EVENT: an order line produces a SALE row on its purchase date, and if
-- it comes back it produces a separate RETURN row on the return date. Signs are set
-- so the two sum correctly with no special casing:
--
--   gross_sales    positive on SALE, zero on RETURN
--   discounts      negative always
--   returns        zero on SALE, negative on RETURN
--   net_sales      gross_sales + discounts + returns   <- plain addition
--
-- Row type is part of the grain, so a day where a SKU both sells and refunds
-- produces two rows and each side stays independently auditable. Aggregate away the
-- row type in BI.
--
-- RECONCILING TO core.amazon_seller.sales_over_time. Sum net_sales over the SALE
-- rows for a closed month and you land within a fraction of a percent of Amazon's
-- ordered_product_sales. It is not exact and it cannot be - see the README - so
-- treat a consistent small gap as expected and a growing one as a bug.

WITH sales AS (
    SELECT
        o.purchase_date                     AS date,
        o.amazon_seller,
        o.marketplace,
        o.asin,
        o.sku,
        'SALE'                              AS report_row_type,
        o.currency,
        o.amazon_order_id,
        o.fulfillment_channel,
        o.is_business_order,
        o.ship_country,

        o.quantity,

        -- Gross is the line price before discounts and excluding tax. Amazon's
        -- item_price is already tax-exclusive, which is why it is used directly and
        -- item_tax is carried separately rather than subtracted.
        o.item_price                        AS gross_sales,
        o.item_promotion_discount           AS discounts,
        CAST(0 AS NUMERIC)                  AS returns,
        0                                   AS returned_quantity,

        o.shipping_price                    AS shipping_charges,
        o.ship_promotion_discount           AS shipping_discounts,
        o.gift_wrap_price                   AS gift_wrap_charges,
        o.item_tax + o.shipping_tax + o.gift_wrap_tax AS taxes,

        CAST(0 AS NUMERIC)                  AS return_label_cost,
        CAST(0 AS NUMERIC)                  AS safe_t_reimbursement,
        0                                   AS resellable_returned_quantity,
        CAST(NULL AS STRING)                AS return_channel,
        CAST(NULL AS DATE)                  AS original_order_date,
        o.is_cancelled
    FROM {{staging.amazon_seller.orders}} o
),

-- Seller-fulfilled returns carry the refunded amount, so they are the money side of
-- the reversal.
mfn_returns AS (
    SELECT
        r.return_date                       AS date,
        r.amazon_seller,
        r.marketplace,
        r.asin,
        r.sku,
        'RETURN'                            AS report_row_type,
        r.currency,
        r.amazon_order_id,
        CAST(NULL AS STRING)                AS fulfillment_channel,
        FALSE                               AS is_business_order,
        CAST(NULL AS STRING)                AS ship_country,

        r.return_quantity                   AS quantity,

        CAST(0 AS NUMERIC)                  AS gross_sales,
        CAST(0 AS NUMERIC)                  AS discounts,
        r.refunded_amount                   AS returns,
        r.return_quantity                   AS returned_quantity,

        CAST(0 AS NUMERIC)                  AS shipping_charges,
        CAST(0 AS NUMERIC)                  AS shipping_discounts,
        CAST(0 AS NUMERIC)                  AS gift_wrap_charges,
        CAST(0 AS NUMERIC)                  AS taxes,

        r.return_label_cost,
        r.safe_t_reimbursement,
        0                                   AS resellable_returned_quantity,
        r.return_channel,
        r.order_date                        AS original_order_date,
        FALSE                               AS is_cancelled
    FROM {{staging.amazon_seller.returns}} r
),

-- FBA returns carry units and condition but NO refunded amount - Amazon leaves that
-- money in the settlement report. So these rows reverse the QUANTITY and value it at
-- the SKU's average realised price rather than inventing a refund figure. That keeps
-- unit-level return rates exact and makes the money an explicit estimate instead of
-- a silent zero.
avg_price AS (
    SELECT
        amazon_seller,
        marketplace,
        sku,
        SAFE_DIVIDE(SUM(item_price + item_promotion_discount), SUM(quantity)) AS avg_net_unit_price
    FROM {{staging.amazon_seller.orders}}
    WHERE quantity > 0
    GROUP BY 1, 2, 3
),

fba_returns AS (
    SELECT
        f.return_date                       AS date,
        f.amazon_seller,
        -- The FBA returns report carries no marketplace column. Resolve it from the
        -- listing rather than defaulting, so single-marketplace accounts are exact
        -- and multi-marketplace ones are visibly NULL instead of quietly wrong.
        l.marketplace,
        f.asin,
        f.sku,
        'RETURN'                            AS report_row_type,
        CAST(NULL AS STRING)                AS currency,
        f.amazon_order_id,
        'afn'                               AS fulfillment_channel,
        FALSE                               AS is_business_order,
        CAST(NULL AS STRING)                AS ship_country,

        f.return_quantity                   AS quantity,

        CAST(0 AS NUMERIC)                  AS gross_sales,
        CAST(0 AS NUMERIC)                  AS discounts,
        -- Estimated, not reported. NULL average price (a SKU that has never sold in
        -- the synced window) yields 0 rather than NULL so the equation still holds.
        CAST(COALESCE(f.return_quantity * p.avg_net_unit_price, 0) AS NUMERIC) AS returns,
        f.return_quantity                   AS returned_quantity,

        CAST(0 AS NUMERIC)                  AS shipping_charges,
        CAST(0 AS NUMERIC)                  AS shipping_discounts,
        CAST(0 AS NUMERIC)                  AS gift_wrap_charges,
        CAST(0 AS NUMERIC)                  AS taxes,

        CAST(0 AS NUMERIC)                  AS return_label_cost,
        CAST(0 AS NUMERIC)                  AS safe_t_reimbursement,

        -- The distinction that decides what a return actually cost. A SELLABLE unit
        -- goes back on the shelf and you lost only the fees; anything else is gone
        -- and you lost the COGS too.
        CASE WHEN f.is_resellable THEN ABS(f.return_quantity) ELSE 0 END AS resellable_returned_quantity,

        f.return_channel,
        CAST(NULL AS DATE)                  AS original_order_date,
        FALSE                               AS is_cancelled
    FROM {{staging.amazon_seller.fba_returns}} f
    LEFT JOIN {{staging.amazon_seller.listings}} l
           ON l.amazon_seller = f.amazon_seller AND l.sku = f.sku
    LEFT JOIN avg_price p
           ON p.amazon_seller = f.amazon_seller
          AND p.marketplace   = l.marketplace
          AND p.sku           = f.sku
),

events AS (
    SELECT * FROM sales
    UNION ALL
    SELECT * FROM mfn_returns
    UNION ALL
    SELECT * FROM fba_returns
)

SELECT
    e.date,
    e.amazon_seller,
    e.marketplace,
    e.asin,
    e.sku,
    e.report_row_type,

    -- Canonical listing attributes beat the order-line snapshot, which was taken at
    -- purchase time and goes stale when a product is renamed or relisted.
    COALESCE(l.product_name, e.sku)          AS product_name,
    l.fulfillment_channel                   AS listing_fulfillment_channel,
    l.listing_status,

    ANY_VALUE(e.currency)                   AS currency,

    -- The sales equation.
    SUM(e.quantity)                         AS quantity,
    ROUND(SUM(e.gross_sales), 2)            AS gross_sales,
    ROUND(SUM(e.discounts), 2)              AS discounts,
    ROUND(SUM(e.returns), 2)                AS returns,
    ROUND(SUM(e.gross_sales + e.discounts + e.returns), 2) AS net_sales,

    ROUND(SUM(e.shipping_charges), 2)       AS shipping_charges,
    ROUND(SUM(e.shipping_discounts), 2)     AS shipping_discounts,
    ROUND(SUM(e.gift_wrap_charges), 2)      AS gift_wrap_charges,
    ROUND(SUM(e.taxes), 2)                  AS taxes,

    -- Two totals, because the UI and finance want different ones. Ship both and let
    -- each consumer pick; arguing about which is "correct" wastes a quarter.
    ROUND(SUM(e.gross_sales + e.discounts + e.returns
              + e.shipping_charges + e.shipping_discounts + e.gift_wrap_charges), 2)
                                            AS total_sales,
    ROUND(SUM(e.gross_sales + e.discounts + e.returns
              + e.shipping_charges + e.shipping_discounts + e.gift_wrap_charges
              + e.taxes), 2)                AS total_sales_incl_tax,

    -- Returns detail.
    SUM(e.returned_quantity)                AS returned_quantity,
    SUM(e.resellable_returned_quantity)     AS resellable_returned_quantity,
    ROUND(SUM(e.return_label_cost), 2)      AS return_label_cost,
    ROUND(SUM(e.safe_t_reimbursement), 2)   AS safe_t_reimbursement,
    ANY_VALUE(e.return_channel)             AS return_channel,

    -- Return lag in days, available on MFN rows only (the FBA report has no order
    -- date). Averaged over the rows on this day, which is why it is a metric rather
    -- than a dimension.
    ROUND(AVG(DATE_DIFF(e.date, e.original_order_date, DAY)), 1) AS avg_days_to_return,

    -- Counting. An order line can appear on several days; COUNT(DISTINCT) on the
    -- SALE rows is the only safe order count.
    COUNT(DISTINCT CASE WHEN e.report_row_type = 'SALE' THEN e.amazon_order_id END) AS orders,

    -- Dimensions.
    ANY_VALUE(e.fulfillment_channel)        AS fulfillment_channel,
    LOGICAL_OR(e.is_business_order)         AS has_business_order,
    LOGICAL_OR(e.is_cancelled)              AS has_cancelled_line
FROM events e
LEFT JOIN {{staging.amazon_seller.listings}} l
       ON l.amazon_seller = e.amazon_seller
      AND l.marketplace   = e.marketplace
      AND l.sku           = e.sku
GROUP BY e.date, e.amazon_seller, e.marketplace, e.asin, e.sku, e.report_row_type,
         l.product_name, l.fulfillment_channel, l.listing_status
