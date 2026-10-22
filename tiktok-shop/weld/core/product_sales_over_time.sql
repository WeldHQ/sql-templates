-- core.tiktok_shop.product_sales_over_time
-- Sales by product and SKU over time, event-based, and reconciling to
-- core.tiktok_shop.sales_over_time on net_sales and units.
--
-- Grain: day x account x shop x currency x product x SKU x row type, where row
-- type is SALE, CANCELLATION or RETURN. Each event lands on the day it happened
-- in the shop's local time (see staging.tiktok_shop.shop):
--   SALE          the order's paid time (created time for cash on delivery)
--   CANCELLATION  the order's cancel time, for every line TikTok marks CANCELLED
--   RETURN        the day a return or refund request completed
-- So a June order refunded in July reduces July, and history does not restate.
--
-- ONE LINE ITEM IS ONE UNIT. TikTok has no quantity column: units are counted.
--
-- The sales equation, all reversals stored negative so it is plain addition:
--   net_sales = gross_sales + seller_discounts + platform_discounts
--             + cancellations + returns
-- net_sales is what customers paid for products. platform_discounts are funded
-- by TikTok and paid back to you in settlement, so seller revenue before fees is
-- net_sales - platform_discounts; core.tiktok_shop.settlement_ledger has the
-- payout view.
--
-- Left out on purpose: unpaid orders (no money yet), free sample orders sent to
-- creators and free replacement orders (they add units at zero price).
--
-- Depends on: staging.tiktok_shop.order, .order_line_items, .return_order,
--             .return_order_line_items, .shop

WITH shop AS (
    SELECT tiktok_account, shop_id, ANY_VALUE(report_timezone) AS report_timezone
    FROM {{staging.tiktok_shop.shop}}
    GROUP BY tiktok_account, shop_id
),

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

sale_events AS (
    SELECT
        DATE(COALESCE(paid_at, created_at), report_timezone) AS date,
        tiktok_account, shop_id, currency, product_id, sku_id, seller_sku,
        product_name, sku_name,
        'SALE'                 AS report_row_type,
        1                      AS units,
        original_price         AS gross_sales,
        -seller_discount       AS seller_discounts,
        -platform_discount     AS platform_discounts,
        CAST(0 AS NUMERIC)     AS cancellations,
        CAST(0 AS NUMERIC)     AS returns
    FROM lines
),

-- A cancelled line reverses what the customer paid for it. TikTok has no
-- per-line cancel time, so a line cancelled while the rest of the order ships
-- lands on the order's cancel time, or its last update when that is empty.
cancel_events AS (
    SELECT
        DATE(COALESCE(cancelled_at, updated_at), report_timezone) AS date,
        tiktok_account, shop_id, currency, product_id, sku_id, seller_sku,
        product_name, sku_name,
        'CANCELLATION'         AS report_row_type,
        -1                     AS units,
        CAST(0 AS NUMERIC)     AS gross_sales,
        CAST(0 AS NUMERIC)     AS seller_discounts,
        CAST(0 AS NUMERIC)     AS platform_discounts,
        -sale_price            AS cancellations,
        CAST(0 AS NUMERIC)     AS returns
    FROM lines
    WHERE display_status = 'CANCELLED'
),

-- Only requests that completed moved money. Replacements move none. A line that
-- was cancelled is already reversed above, so a refund record on it is skipped
-- rather than counted twice.
completed_returns AS (
    SELECT tiktok_account, shop_id, return_id, updated_at
    FROM {{staging.tiktok_shop.return_order}}
    WHERE return_status = 'RETURN_OR_REFUND_REQUEST_COMPLETE'
      AND return_type != 'REPLACEMENT'
),

return_events AS (
    SELECT
        DATE(r.updated_at, l.report_timezone) AS date,
        rl.tiktok_account, rl.shop_id, l.currency, l.product_id, l.sku_id, l.seller_sku,
        l.product_name, l.sku_name,
        'RETURN'               AS report_row_type,
        -1                     AS units,
        CAST(0 AS NUMERIC)     AS gross_sales,
        CAST(0 AS NUMERIC)     AS seller_discounts,
        CAST(0 AS NUMERIC)     AS platform_discounts,
        CAST(0 AS NUMERIC)     AS cancellations,
        -rl.refund_subtotal    AS returns
    FROM {{staging.tiktok_shop.return_order_line_items}} rl
    JOIN completed_returns r USING (tiktok_account, shop_id, return_id)
    JOIN lines l
      ON  l.tiktok_account = rl.tiktok_account
      AND l.shop_id        = rl.shop_id
      AND l.line_item_id   = rl.line_item_id
    WHERE l.display_status != 'CANCELLED'
),

events AS (
    SELECT * FROM sale_events
    UNION ALL SELECT * FROM cancel_events
    UNION ALL SELECT * FROM return_events
)

SELECT
    date,
    tiktok_account,
    shop_id,
    currency,
    product_id,
    sku_id,
    report_row_type,
    -- Names can change over a product's life; one name per group is shown, the ids are the key.
    ANY_VALUE(seller_sku)                 AS seller_sku,
    ANY_VALUE(product_name)               AS product_name,
    ANY_VALUE(sku_name)                   AS sku_name,
    SUM(units)                            AS units,
    ROUND(SUM(gross_sales), 2)            AS gross_sales,
    ROUND(SUM(seller_discounts), 2)       AS seller_discounts,
    ROUND(SUM(platform_discounts), 2)     AS platform_discounts,
    ROUND(SUM(cancellations), 2)          AS cancellations,
    ROUND(SUM(returns), 2)                AS returns,
    ROUND(SUM(gross_sales + seller_discounts + platform_discounts
              + cancellations + returns), 2) AS net_sales
FROM events
GROUP BY date, tiktok_account, shop_id, currency, product_id, sku_id, report_row_type
