-- stg_woocommerce__product
-- Products and their variations. WordPress stores both as posts: post_type
-- 'product' for the product, 'product_variation' for each variation, whose
-- post_parent is the product. Everything else in wp_posts (pages, blog posts,
-- legacy orders) is dropped here.
--
-- post_title is the CURRENT name. For the name at the time of sale, use
-- order_items.order_item_name.

SELECT
    'store_1'                              AS woocommerce_store,
    CAST(ID AS INT64)                      AS post_id,
    CAST(post_type AS STRING)              AS post_type,
    NULLIF(CAST(post_parent AS INT64), 0)  AS parent_product_id,
    NULLIF(TRIM(CAST(post_title AS STRING)), '') AS title,
    CAST(post_name AS STRING)              AS slug,
    CAST(post_status AS STRING)            AS post_status
FROM {{ source('woocommerce', 'wp_posts') }}
WHERE post_type IN ('product', 'product_variation')
QUALIFY ROW_NUMBER() OVER (PARTITION BY ID ORDER BY post_modified_gmt DESC) = 1
