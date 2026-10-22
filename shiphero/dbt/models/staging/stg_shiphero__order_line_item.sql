-- stg_shiphero__order_line_item
-- Thin wrapper over raw `order_line_item`. One row per order line.
--
-- `quantity` is what was ordered; `quantity_shipped` what has left the warehouse
-- so far. Both are current state and move as the order is fulfilled.

SELECT
    'account_1'                                    AS shiphero_account,
    CAST(id AS STRING)                             AS line_item_id,
    CAST(order_id AS STRING)                       AS order_id,
    NULLIF(TRIM(CAST(sku AS STRING)), '')          AS sku,
    NULLIF(TRIM(CAST(product_name AS STRING)), '') AS product_name,
    CAST(quantity AS INT64)                        AS quantity,
    CAST(quantity_shipped AS INT64)                AS quantity_shipped,
    CAST(quantity_pending_fulfillment AS INT64)    AS quantity_pending_fulfillment,
    CAST(backorder_quantity AS INT64)              AS backorder_quantity,
    SAFE_CAST(price AS NUMERIC)                    AS unit_price,
    LOWER(NULLIF(TRIM(CAST(fulfillment_status AS STRING)), '')) AS fulfillment_status
FROM {{ source('shiphero', 'order_line_item') }}
