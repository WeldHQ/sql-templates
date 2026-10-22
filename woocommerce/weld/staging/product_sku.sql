-- staging.woocommerce.product_sku
-- SKU per product or variation, from WordPress' key/value post meta (_sku).
-- wp_postmeta holds every meta key for every post on the site, so it is filtered
-- to the one key needed. Blank SKUs become NULL.

SELECT
    'store_1'                                AS woocommerce_store,
    CAST(post_id AS INT64)                   AS post_id,
    NULLIF(TRIM(CAST(meta_value AS STRING)), '') AS sku
FROM {{raw.woocommerce.wp_postmeta}}
WHERE meta_key = '_sku'
QUALIFY ROW_NUMBER() OVER (PARTITION BY post_id ORDER BY meta_id DESC) = 1
