-- stg_shopify__inventory_item
-- Current cost per inventory item. Shopify stores cost here, not on the variant.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)             AS inventory_item_id,
    CAST(sku AS STRING)           AS sku,
    CAST(cost AS NUMERIC)         AS cost,
    CAST(created_at AS TIMESTAMP) AS created_at,
    CAST(updated_at AS TIMESTAMP) AS updated_at
FROM {{ source('shopify', 'inventory_item') }}
WHERE sku IS NOT NULL AND TRIM(CAST(sku AS STRING)) != ''
