-- stg_shopify__product
-- Canonical product attributes. order_line carries a snapshot taken at purchase
-- time; prefer these when a product was later renamed or recategorised.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)            AS product_id,
    CAST(title AS STRING)        AS product_title,
    CAST(product_type AS STRING) AS product_type,
    CAST(vendor AS STRING)       AS vendor,
    LOWER(CAST(status AS STRING)) AS status
FROM {{ source('shopify', 'product') }}
