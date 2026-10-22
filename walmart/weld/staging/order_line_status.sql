-- staging.walmart.order_line_status
-- Thin wrapper over raw `order_line_status`: the status of each order line,
-- split by quantity (a two-unit line can be one Shipped and one Cancelled).
-- Status is upper-cased: CREATED, ACKNOWLEDGED, SHIPPED, DELIVERED, CANCELLED.

SELECT
    'seller_1'                                          AS walmart_seller,
    CAST(purchase_order_id AS STRING)                   AS purchase_order_id,
    CAST(line_number AS STRING)                         AS line_number,
    CAST(index AS INT64)                                AS status_index,
    UPPER(CAST(status AS STRING))                       AS status,
    COALESCE(CAST(status_quantity_amount AS NUMERIC), 0) AS status_quantity,
    CAST(cancellation_reason AS STRING)                 AS cancellation_reason,
    CAST(tracking_info_ship_date_time AS TIMESTAMP)     AS shipped_at
FROM {{raw.walmart.order_line_status}}
WHERE purchase_order_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_order_id, line_number, index ORDER BY _weld_synced DESC) = 1
