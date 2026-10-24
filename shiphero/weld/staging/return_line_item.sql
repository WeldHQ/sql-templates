-- staging.shiphero.return_line_item
-- Thin wrapper over raw `return_line_item`. One row per product on a return.
-- The SKU is not on this table; core resolves it through product_id.

SELECT
    'account_1'                                       AS shiphero_account,
    CAST(id AS STRING)                                AS return_line_item_id,
    CAST(return_id AS STRING)                         AS return_id,
    CAST(product_id AS STRING)                        AS product_id,
    CAST(warehouse_id AS STRING)                      AS warehouse_id,
    CAST(quantity AS INT64)                           AS quantity,
    CAST(quantity_received AS INT64)                  AS quantity_received,
    CAST(restock AS INT64)                            AS quantity_restocked,
    NULLIF(TRIM(CAST(reason AS STRING)), '')          AS reason,
    LOWER(NULLIF(TRIM(CAST(condition AS STRING)), '')) AS condition,
    CAST(created_at AS TIMESTAMP)                     AS created_at
FROM {{raw.shiphero.return_line_item}}
