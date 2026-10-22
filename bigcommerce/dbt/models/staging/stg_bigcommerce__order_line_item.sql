-- stg_bigcommerce__order_line_item
-- Thin wrapper over raw `order_line_item` (the order's products). Casts and renames.
--
-- Line totals are BEFORE discounts: BigCommerce records the discounts applied to a
-- line separately, in order_line_item_discount. Cost is the product's cost price as
-- it stood when the order was placed, so margin on old orders does not move when
-- you edit a cost today.

SELECT
    'store_1'                                           AS bigcommerce_store,
    CAST(id AS INT64)                                   AS order_line_item_id,
    CAST(order_id AS INT64)                             AS order_id,
    CAST(product_id AS INT64)                           AS product_id,
    CAST(variant_id AS INT64)                           AS variant_id,
    CAST(parent_order_product_id AS INT64)              AS parent_order_line_item_id,
    COALESCE(CAST(is_bundled_product AS BOOL), FALSE)   AS is_bundled_product,
    NULLIF(TRIM(CAST(name AS STRING)), '')              AS product_name,
    NULLIF(TRIM(CAST(sku AS STRING)), '')               AS sku,
    NULLIF(TRIM(CAST(brand AS STRING)), '')             AS brand,
    -- physical, digital or giftcertificate
    LOWER(NULLIF(TRIM(CAST(type AS STRING)), ''))       AS line_type,
    CAST(quantity AS INT64)                             AS quantity,
    CAST(price_ex_tax AS NUMERIC)                       AS price_ex_tax,
    CAST(total_ex_tax AS NUMERIC)                       AS total_ex_tax,
    CAST(total_tax AS NUMERIC)                          AS total_tax,
    CAST(total_inc_tax AS NUMERIC)                      AS total_inc_tax,
    CAST(base_cost_price AS NUMERIC)                    AS unit_cost,
    -- Current state, not dated: the dated refunds are in refund / refund_line_item.
    CAST(quantity_refunded AS NUMERIC)                  AS quantity_refunded,
    CAST(refund_amount AS NUMERIC)                      AS refund_amount
FROM {{ source('bigcommerce', 'order_line_item') }}
