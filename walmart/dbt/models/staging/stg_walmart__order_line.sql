-- stg_walmart__order_line
-- Thin wrapper over raw `order_line`: one row per purchase order line.
--
-- Walmart normally issues one unit per line; quantity is kept anyway so a
-- multi-unit line is counted correctly.

SELECT
    'seller_1'                                         AS walmart_seller,
    CAST(purchase_order_id AS STRING)                  AS purchase_order_id,
    CAST(line_number AS STRING)                        AS line_number,
    CAST(item_sku AS STRING)                           AS sku,
    CAST(item_product_name AS STRING)                  AS product_name,
    CAST(item_condition AS STRING)                     AS item_condition,
    COALESCE(CAST(order_line_quantity_amount AS NUMERIC), 1) AS quantity,
    CAST(status_date AS TIMESTAMP)                     AS status_at,
    CAST(fulfillment_fulfillment_option AS STRING)     AS fulfillment_option,
    CAST(fulfillment_shipping_program_type AS STRING)  AS shipping_program_type,
    CAST(refund_refund_id AS STRING)                   AS refund_id
FROM {{ source('walmart', 'order_line') }}
WHERE purchase_order_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_order_id, line_number ORDER BY _weld_synced DESC) = 1
