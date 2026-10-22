-- stg_shiphero__shipment_line_item
-- Thin wrapper over raw `shipment_line_item`. One row per order line per shipment,
-- with the quantity that went out in that shipment.

SELECT
    'account_1'                            AS shiphero_account,
    CAST(id AS STRING)                     AS shipment_line_item_id,
    CAST(shipment_id AS STRING)            AS shipment_id,
    CAST(line_item_id AS STRING)           AS line_item_id,
    CAST(shipping_label_id AS STRING)      AS shipping_label_id,
    CAST(quantity AS INT64)                AS quantity
FROM {{ source('shiphero', 'shipment_line_item') }}
