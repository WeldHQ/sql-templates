-- core_walmart__product_sales_over_time
-- Sales by SKU per order day, from the Orders API, reconciling to
-- core.walmart.sales_over_time on net sales and units.
--
-- Grain: order day x seller x currency x ship node type x SKU. The day is the
-- order date in the seller's timezone (staging.walmart.seller).
--
-- ORDER-DATE VIEW, NOT AN EVENT LOG. Walmart's Orders API says what was
-- cancelled and refunded on each line but not when, so cancellations and refunds
-- are attributed back to the day the order was placed. A May order refunded in
-- July lowers May, and recent days keep moving as refunds arrive. For refunds on
-- the day the money moved, use core.walmart.settlement_ledger.
--
-- The sales equation, reversals negative so it is plain addition:
--   net_sales = gross_sales + cancellations + refunds
-- gross_sales is the PRODUCT charge on every line. A cancelled share of a line
-- reverses the same share of its charge. Refunds are the refunded PRODUCT
-- charges; a line cancelled in full has its refunds ignored so it is not reversed
-- twice.
--
-- Depends on: staging.walmart.order, .order_line, .order_line_charge,
--             .order_line_status, .order_line_refund_charge, .seller

WITH seller AS (
    SELECT walmart_seller, ANY_VALUE(report_timezone) AS report_timezone
    FROM {{ ref('stg_walmart__seller') }}
    GROUP BY walmart_seller
),

charges AS (
    SELECT
        walmart_seller, purchase_order_id, line_number,
        SUM(CASE WHEN charge_type = 'PRODUCT' THEN charge_amount ELSE 0 END) AS product_amount
    FROM {{ ref('stg_walmart__order_line_charge') }}
    GROUP BY 1, 2, 3
),

cancelled AS (
    SELECT
        walmart_seller, purchase_order_id, line_number,
        SUM(CASE WHEN status = 'CANCELLED' THEN status_quantity ELSE 0 END) AS cancelled_quantity
    FROM {{ ref('stg_walmart__order_line_status') }}
    GROUP BY 1, 2, 3
),

refunds AS (
    SELECT
        walmart_seller, purchase_order_id, line_number,
        SUM(CASE WHEN charge_type = 'PRODUCT' THEN refund_amount ELSE 0 END) AS product_refund
    FROM {{ ref('stg_walmart__order_line_refund_charge') }}
    GROUP BY 1, 2, 3
),

lines AS (
    SELECT
        DATE(o.ordered_at, s.report_timezone)                       AS date,
        l.walmart_seller,
        o.currency,
        o.ship_node_type,
        l.sku,
        l.product_name,
        l.quantity,
        LEAST(COALESCE(c.cancelled_quantity, 0), l.quantity)        AS cancelled_quantity,
        COALESCE(ch.product_amount, 0)                              AS product_amount,
        COALESCE(r.product_refund, 0)                               AS product_refund
    FROM {{ ref('stg_walmart__order_line') }} l
    JOIN {{ ref('stg_walmart__order') }} o USING (walmart_seller, purchase_order_id)
    JOIN seller s USING (walmart_seller)
    LEFT JOIN charges ch   USING (walmart_seller, purchase_order_id, line_number)
    LEFT JOIN cancelled c  USING (walmart_seller, purchase_order_id, line_number)
    LEFT JOIN refunds r    USING (walmart_seller, purchase_order_id, line_number)
)

SELECT
    date,
    walmart_seller,
    currency,
    ship_node_type,
    sku,
    ANY_VALUE(product_name)                               AS product_name,
    SUM(quantity)                                         AS units_ordered,
    SUM(cancelled_quantity)                               AS units_cancelled,
    SUM(quantity - cancelled_quantity)                    AS units,
    ROUND(SUM(product_amount), 2)                         AS gross_sales,
    ROUND(SUM(-product_amount * SAFE_DIVIDE(cancelled_quantity, quantity)), 2) AS cancellations,
    ROUND(SUM(CASE WHEN cancelled_quantity >= quantity THEN 0 ELSE product_refund END), 2) AS refunds,
    ROUND(SUM(product_amount
              - product_amount * COALESCE(SAFE_DIVIDE(cancelled_quantity, quantity), 0)
              + CASE WHEN cancelled_quantity >= quantity THEN 0 ELSE product_refund END), 2) AS net_sales
FROM lines
GROUP BY date, walmart_seller, currency, ship_node_type, sku
