-- core.walmart.sales_over_time
-- Sales over time for a Walmart Marketplace seller, from the Orders API: the
-- sales equation per order day, with shipping and tax.
--
-- Grain: order day x seller x currency x ship node type. ship_node_type splits
-- seller-fulfilled from Walmart Fulfillment Services (WFS) and 3PL orders. The
-- day is the order date in the seller's timezone (staging.walmart.seller).
--
-- ORDER-DATE VIEW. The Orders API records what was cancelled and refunded on a
-- line but not when, so both are attributed back to the order day. Recent days
-- keep moving as refunds arrive; history from months ago is stable. For refunds
-- dated when the money moved, and for what Walmart actually paid after
-- commission, use core.walmart.settlement_ledger.
--
--   net_sales   = gross_sales + cancellations + refunds
--   total_sales = net_sales + shipping + other_charges + taxes
--
-- Product columns follow exactly the same rules as
-- core.walmart.product_sales_over_time and reconcile with it
-- (dbt/tests/assert_walmart__product_reconciles_to_sales.sql). Keep the two in step.
-- Shipping, other charges and tax are reduced by the cancelled share of their
-- line and by their own refunded amounts.
--
-- Depends on: staging.walmart.order, .order_line, .order_line_charge,
--             .order_line_status, .order_line_refund_charge, .seller

WITH seller AS (
    SELECT walmart_seller, ANY_VALUE(report_timezone) AS report_timezone
    FROM {{staging.walmart.seller}}
    GROUP BY walmart_seller
),

charges AS (
    SELECT
        walmart_seller, purchase_order_id, line_number,
        SUM(CASE WHEN charge_type = 'PRODUCT'  THEN charge_amount ELSE 0 END)          AS product_amount,
        SUM(CASE WHEN charge_type = 'SHIPPING' THEN charge_amount ELSE 0 END)          AS shipping_amount,
        SUM(CASE WHEN charge_type NOT IN ('PRODUCT', 'SHIPPING') OR charge_type IS NULL
                 THEN charge_amount ELSE 0 END)                                         AS other_amount,
        SUM(tax_amount)                                                                 AS tax_amount
    FROM {{staging.walmart.order_line_charge}}
    GROUP BY 1, 2, 3
),

cancelled AS (
    SELECT
        walmart_seller, purchase_order_id, line_number,
        SUM(CASE WHEN status = 'CANCELLED' THEN status_quantity ELSE 0 END) AS cancelled_quantity
    FROM {{staging.walmart.order_line_status}}
    GROUP BY 1, 2, 3
),

refunds AS (
    SELECT
        walmart_seller, purchase_order_id, line_number,
        SUM(CASE WHEN charge_type = 'PRODUCT'  THEN refund_amount ELSE 0 END)          AS product_refund,
        SUM(CASE WHEN charge_type = 'SHIPPING' THEN refund_amount ELSE 0 END)          AS shipping_refund,
        SUM(CASE WHEN charge_type NOT IN ('PRODUCT', 'SHIPPING') OR charge_type IS NULL
                 THEN refund_amount ELSE 0 END)                                         AS other_refund,
        SUM(refund_tax_amount)                                                          AS tax_refund
    FROM {{staging.walmart.order_line_refund_charge}}
    GROUP BY 1, 2, 3
),

lines AS (
    SELECT
        DATE(o.ordered_at, s.report_timezone)                       AS date,
        l.walmart_seller,
        o.currency,
        o.ship_node_type,
        l.purchase_order_id,
        l.quantity,
        LEAST(COALESCE(c.cancelled_quantity, 0), l.quantity)        AS cancelled_quantity,
        COALESCE(ch.product_amount, 0)                              AS product_amount,
        COALESCE(ch.shipping_amount, 0)                             AS shipping_amount,
        COALESCE(ch.other_amount, 0)                                AS other_amount,
        COALESCE(ch.tax_amount, 0)                                  AS tax_amount,
        COALESCE(r.product_refund, 0)                               AS product_refund,
        COALESCE(r.shipping_refund, 0)                              AS shipping_refund,
        COALESCE(r.other_refund, 0)                                 AS other_refund,
        COALESCE(r.tax_refund, 0)                                   AS tax_refund
    FROM {{staging.walmart.order_line}} l
    JOIN {{staging.walmart.order}} o USING (walmart_seller, purchase_order_id)
    JOIN seller s USING (walmart_seller)
    LEFT JOIN charges ch   USING (walmart_seller, purchase_order_id, line_number)
    LEFT JOIN cancelled c  USING (walmart_seller, purchase_order_id, line_number)
    LEFT JOIN refunds r    USING (walmart_seller, purchase_order_id, line_number)
),

-- Share of each line still standing after cancellation, and whether its refunds
-- count (a line cancelled in full has nothing left to refund).
shaped AS (
    SELECT
        *,
        1 - COALESCE(SAFE_DIVIDE(cancelled_quantity, quantity), 0) AS kept_share,
        cancelled_quantity < quantity                              AS refunds_apply
    FROM lines
)

SELECT
    date,
    walmart_seller,
    currency,
    ship_node_type,
    -- An order counts once even when it has several lines; a fully cancelled
    -- order still counts as placed, matching how orders are received.
    COUNT(DISTINCT purchase_order_id)                                               AS orders,
    SUM(quantity)                                                                   AS units_ordered,
    SUM(cancelled_quantity)                                                         AS units_cancelled,
    SUM(quantity - cancelled_quantity)                                              AS units,
    ROUND(SUM(product_amount), 2)                                                   AS gross_sales,
    ROUND(SUM(-product_amount * SAFE_DIVIDE(cancelled_quantity, quantity)), 2)      AS cancellations,
    ROUND(SUM(IF(refunds_apply, product_refund, 0)), 2)                             AS refunds,
    ROUND(SUM(product_amount * kept_share + IF(refunds_apply, product_refund, 0)), 2) AS net_sales,
    ROUND(SUM(shipping_amount * kept_share + IF(refunds_apply, shipping_refund, 0)), 2) AS shipping,
    ROUND(SUM(other_amount * kept_share + IF(refunds_apply, other_refund, 0)), 2)   AS other_charges,
    ROUND(SUM(tax_amount * kept_share + IF(refunds_apply, tax_refund, 0)), 2)       AS taxes,
    ROUND(SUM(product_amount * kept_share + IF(refunds_apply, product_refund, 0)
              + shipping_amount * kept_share + IF(refunds_apply, shipping_refund, 0)
              + other_amount * kept_share + IF(refunds_apply, other_refund, 0)
              + tax_amount * kept_share + IF(refunds_apply, tax_refund, 0)), 2)     AS total_sales
FROM shaped
GROUP BY date, walmart_seller, currency, ship_node_type
