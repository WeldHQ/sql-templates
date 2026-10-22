-- stg_woocommerce__order_product_lookup
-- One row per product line, on orders AND on refunds, from WooCommerce Analytics'
-- product lookup table (what the Products report reads). order_id is the order's
-- id on order lines and the REFUND's id on refund lines; join to order_stats to
-- tell them apart and to reach the original order.
--
-- Money is in store currency. product_net_revenue is the line after coupons,
-- excluding tax and shipping; coupon_amount is the coupon discount allocated to
-- the line. Refund lines carry negative quantity and revenue.
-- variation_id is 0 for a simple product, so it is turned into NULL here.

SELECT
    'store_1'                                AS woocommerce_store,
    CAST(order_item_id AS INT64)             AS order_item_id,
    CAST(order_id AS INT64)                  AS order_id,
    CAST(product_id AS INT64)                AS product_id,
    NULLIF(CAST(variation_id AS INT64), 0)   AS variation_id,
    CAST(customer_id AS INT64)               AS customer_id,
    DATETIME(CAST(date_created AS TIMESTAMP), 'UTC') AS date_created_local,
    CAST(product_qty AS INT64)               AS quantity,
    CAST(product_net_revenue AS NUMERIC)     AS net_revenue,
    CAST(product_gross_revenue AS NUMERIC)   AS gross_revenue_incl_tax_and_shipping,
    COALESCE(CAST(coupon_amount AS NUMERIC), 0)       AS coupon_amount,
    COALESCE(CAST(tax_amount AS NUMERIC), 0)          AS tax_amount,
    COALESCE(CAST(shipping_amount AS NUMERIC), 0)     AS shipping_amount,
    COALESCE(CAST(shipping_tax_amount AS NUMERIC), 0) AS shipping_tax_amount
FROM {{ source('woocommerce', 'wp_wc_order_product_lookup') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY _weld_synced DESC) = 1
