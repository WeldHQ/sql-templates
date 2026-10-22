-- core.tiktok_shop.sales_over_time
-- Sales over time for a TikTok shop: the sales equation per day, with shipping
-- and tax, built from orders and returns.
--
-- Grain: day x account x shop x currency x row type (SALE, CANCELLATION,
-- RETURN). Keeping row type in the grain lets the sale side and the reversal side
-- be checked independently; sum over it in BI. Dates are the shop's local day
-- (see staging.tiktok_shop.shop), and every event lands on the day it happened:
-- sales on payment, cancellations on cancellation, refunds on completion.
--
-- Product columns use exactly the same rules as
-- core.tiktok_shop.product_sales_over_time, and the two reconcile on net_sales
-- and units (dbt/tests/assert_product_reconciles_to_sales.sql). Keep the two in
-- step when changing either.
--
--   net_sales   = gross_sales + seller_discounts + platform_discounts
--               + cancellations + returns
--   total_sales = net_sales + shipping + taxes
--
-- Shipping and tax are order-level. They are reversed when a whole order is
-- cancelled, and refunded shipping and tax are taken from the return lines. A
-- single cancelled line inside a shipped order does not reverse any shipping.
--
-- This is the customer-facing view of sales. For what TikTok actually paid out
-- after commission, fees and shipping, use core.tiktok_shop.settlement_ledger.
-- For TikTok's own GMV figure, use core.tiktok_shop.shop_performance.
--
-- Depends on: staging.tiktok_shop.order, .order_line_items, .return_order,
--             .return_order_line_items, .shop

WITH shop AS (
    SELECT tiktok_account, shop_id, ANY_VALUE(report_timezone) AS report_timezone
    FROM {{staging.tiktok_shop.shop}}
    GROUP BY tiktok_account, shop_id
),

-- Same filter as product_sales_over_time: no unpaid, sample or replacement orders.
orders AS (
    SELECT o.*, s.report_timezone
    FROM {{staging.tiktok_shop.order}} o
    JOIN shop s USING (tiktok_account, shop_id)
    WHERE o.order_status != 'UNPAID'
      AND (o.paid_at IS NOT NULL OR o.is_cod)
      AND NOT o.is_sample_order
      AND NOT o.is_replacement_order
),

lines AS (
    SELECT l.*, o.report_timezone, o.paid_at, o.created_at, o.cancelled_at, o.updated_at
    FROM {{staging.tiktok_shop.order_line_items}} l
    JOIN orders o USING (tiktok_account, shop_id, order_id)
),

completed_returns AS (
    SELECT tiktok_account, shop_id, return_id, updated_at
    FROM {{staging.tiktok_shop.return_order}}
    WHERE return_status = 'RETURN_OR_REFUND_REQUEST_COMPLETE'
      AND return_type != 'REPLACEMENT'
),

events AS (
    -- Sales: product lines, on the paid day.
    SELECT
        DATE(COALESCE(paid_at, created_at), report_timezone) AS date,
        tiktok_account, shop_id, currency,
        'SALE' AS report_row_type,
        CAST(NULL AS STRING) AS order_id,
        1 AS units, original_price AS gross_sales, -seller_discount AS seller_discounts,
        -platform_discount AS platform_discounts, CAST(0 AS NUMERIC) AS cancellations,
        CAST(0 AS NUMERIC) AS returns, CAST(0 AS NUMERIC) AS shipping, CAST(0 AS NUMERIC) AS taxes
    FROM lines

    UNION ALL
    -- Sales: order-level shipping and tax, once per order. order_id is carried
    -- only so orders can be counted.
    SELECT
        DATE(COALESCE(paid_at, created_at), report_timezone),
        tiktok_account, shop_id, currency,
        'SALE', order_id,
        0, 0, 0, 0, 0, 0,
        COALESCE(shipping_fee, 0), COALESCE(tax, 0)
    FROM orders

    UNION ALL
    -- Cancelled lines.
    SELECT
        DATE(COALESCE(cancelled_at, updated_at), report_timezone),
        tiktok_account, shop_id, currency,
        'CANCELLATION', NULL,
        -1, 0, 0, 0, -sale_price, 0, 0, 0
    FROM lines
    WHERE display_status = 'CANCELLED'

    UNION ALL
    -- Whole-order cancellations also reverse shipping and tax.
    SELECT
        DATE(COALESCE(cancelled_at, updated_at), report_timezone),
        tiktok_account, shop_id, currency,
        'CANCELLATION', NULL,
        0, 0, 0, 0, 0, 0,
        -COALESCE(shipping_fee, 0), -COALESCE(tax, 0)
    FROM orders
    WHERE order_status = 'CANCELLED'

    UNION ALL
    -- Completed refunds, on the completion day. Lines already cancelled are
    -- skipped so nothing is reversed twice.
    SELECT
        DATE(r.updated_at, l.report_timezone),
        rl.tiktok_account, rl.shop_id, l.currency,
        'RETURN', NULL,
        -1, 0, 0, 0, 0, -rl.refund_subtotal,
        -rl.refund_shipping_fee, -rl.refund_tax
    FROM {{staging.tiktok_shop.return_order_line_items}} rl
    JOIN completed_returns r USING (tiktok_account, shop_id, return_id)
    JOIN lines l
      ON  l.tiktok_account = rl.tiktok_account
      AND l.shop_id        = rl.shop_id
      AND l.line_item_id   = rl.line_item_id
    WHERE l.display_status != 'CANCELLED'
)

SELECT
    date,
    tiktok_account,
    shop_id,
    currency,
    report_row_type,
    -- Each order is counted once, on its paid day.
    COUNT(DISTINCT order_id)                        AS orders,
    SUM(units)                                      AS units,
    ROUND(SUM(gross_sales), 2)                      AS gross_sales,
    ROUND(SUM(seller_discounts), 2)                 AS seller_discounts,
    ROUND(SUM(platform_discounts), 2)               AS platform_discounts,
    ROUND(SUM(cancellations), 2)                    AS cancellations,
    ROUND(SUM(returns), 2)                          AS returns,
    ROUND(SUM(gross_sales + seller_discounts + platform_discounts
              + cancellations + returns), 2)        AS net_sales,
    ROUND(SUM(shipping), 2)                         AS shipping,
    ROUND(SUM(taxes), 2)                            AS taxes,
    ROUND(SUM(gross_sales + seller_discounts + platform_discounts
              + cancellations + returns + shipping + taxes), 2) AS total_sales
FROM events
GROUP BY date, tiktok_account, shop_id, currency, report_row_type
