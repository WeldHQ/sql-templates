-- staging.woocommerce.order_items
-- Every line on every order and refund: products, shipping, fees, coupons, taxes.
-- Used here only for order_item_name, the product name as it read when the order
-- was placed. That name survives the product being renamed or deleted, which the
-- product catalog (wp_posts) does not.

SELECT
    'store_1'                              AS woocommerce_store,
    CAST(order_item_id AS INT64)           AS order_item_id,
    CAST(order_id AS INT64)                AS order_id,
    CAST(order_item_type AS STRING)        AS order_item_type,
    NULLIF(TRIM(CAST(order_item_name AS STRING)), '') AS order_item_name
FROM {{raw.woocommerce.wp_woocommerce_order_items}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY _weld_synced DESC) = 1
