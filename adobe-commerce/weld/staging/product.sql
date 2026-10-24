-- staging.adobe_commerce.product
-- The product catalog's entity table: id, SKU and product type. Names, prices and
-- other attributes live in Magento's EAV attribute tables
-- (catalog_product_entity_varchar, _decimal, ...), which are not synced, so the
-- name used in reports is the one copied onto the order item at the time of sale.

SELECT
    'store_1'                           AS adobe_commerce_store,
    CAST(entity_id AS INT64)            AS product_id,
    CAST(sku AS STRING)                 AS sku,
    CAST(type_id AS STRING)             AS product_type,
    CAST(attribute_set_id AS INT64)     AS attribute_set_id,
    CAST(created_at AS TIMESTAMP)       AS created_at,
    CAST(updated_at AS TIMESTAMP)       AS updated_at
FROM {{raw.adobe_commerce.catalog_product_entity}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY entity_id ORDER BY _weld_synced DESC) = 1
