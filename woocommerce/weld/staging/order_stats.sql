-- staging.woocommerce.order_stats
-- One row per order AND per refund, from WooCommerce Analytics' own order table.
-- This is the table the WooCommerce Analytics Revenue and Orders reports read, and
-- it is filled the same way whether the store keeps orders in posts/postmeta or in
-- the newer order tables (HPOS), which is why everything here starts from it.
--
-- A refund is its own row: parent_id points at the original order, the amounts are
-- negative, and status is copied from the parent order. parent_id = 0 means an
-- order.
--
-- Time: date_created, date_paid and date_completed are the store's LOCAL wall-clock
-- time (MySQL DATETIME, no zone). They arrive as timestamps whose UTC reading is
-- that wall clock, so they are converted to DATETIME at UTC here, which recovers the
-- store-local value exactly. Do not convert them to a time zone again downstream.
-- date_created_gmt is real UTC.
--
-- Table prefix: wp_ is WordPress' default. If your install uses another prefix,
-- change the raw table name here and in the other staging models.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different woocommerce_store label.

SELECT
    'store_1'                                          AS woocommerce_store,
    CAST(order_id AS INT64)                            AS order_id,
    CAST(parent_id AS INT64)                           AS parent_id,
    CAST(parent_id AS INT64) != 0                      AS is_refund,
    CAST(status AS STRING)                             AS status,
    CAST(customer_id AS INT64)                         AS customer_id,
    CAST(returning_customer AS INT64) = 1              AS is_returning_customer,
    DATETIME(CAST(date_created AS TIMESTAMP), 'UTC')   AS date_created_local,
    DATETIME(CAST(date_paid AS TIMESTAMP), 'UTC')      AS date_paid_local,
    DATETIME(CAST(date_completed AS TIMESTAMP), 'UTC') AS date_completed_local,
    CAST(date_created_gmt AS TIMESTAMP)                AS date_created_utc,
    CAST(num_items_sold AS INT64)                      AS num_items_sold,
    CAST(total_sales AS NUMERIC)                       AS total_sales,
    CAST(tax_total AS NUMERIC)                         AS tax_total,
    CAST(shipping_total AS NUMERIC)                    AS shipping_total,
    CAST(net_total AS NUMERIC)                         AS net_total
FROM {{raw.woocommerce.wp_wc_order_stats}}
-- An incremental sync can land a changed order more than once; keep the latest.
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY _weld_synced DESC) = 1
