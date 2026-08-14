-- stg_shopify__order_line
-- Product identity and line money. Gift cards are NOT filtered here - staging
-- stays neutral and consumers decide. `is_gift_card` and `requires_shipping` are
-- exposed because the sales report needs them to classify orders.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)             AS line_id,
    CAST(order_id AS INT64)       AS order_id,
    CAST(product_id AS INT64)     AS product_id,
    CAST(variant_id AS INT64)     AS variant_id,
    CAST(sku AS STRING)           AS sku,
    NULLIF(TRIM(CAST(title AS STRING)), '') AS product_title,
    CAST(variant_title AS STRING) AS variant_title,
    CAST(vendor AS STRING)        AS vendor,
    CAST(quantity AS INT64)       AS quantity,
    COALESCE(CAST(gift_card AS BOOL), FALSE)       AS is_gift_card,
    COALESCE(CAST(requires_shipping AS BOOL), TRUE) AS requires_shipping,
    COALESCE(CAST(price_set_shop_money_amount AS NUMERIC), CAST(price AS NUMERIC)) AS unit_price,
    COALESCE(CAST(price_set_shop_money_amount AS NUMERIC), CAST(price AS NUMERIC))
      * CAST(quantity AS INT64) AS gross_sales,
    COALESCE(CAST(total_discount_set_shop_money_amount AS NUMERIC),
             CAST(total_discount AS NUMERIC), 0) AS discounts
FROM {{ source('shopify', 'order_line') }}
