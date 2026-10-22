-- staging.traede.product
-- Thin wrapper over raw `product`. One row per product (style). Sizes and colours
-- are variants, see staging.traede.variant.

SELECT
    'account_1'                                     AS traede_account,
    CAST(id AS STRING)                              AS product_id,
    NULLIF(TRIM(CAST(item_number AS STRING)), '')   AS item_number,
    NULLIF(TRIM(CAST(name AS STRING)), '')          AS product_name,
    CAST(collection_id AS STRING)                   AS collection_id,
    CAST(subbrand_id AS STRING)                     AS subbrand_id
FROM {{raw.traede.product}}
