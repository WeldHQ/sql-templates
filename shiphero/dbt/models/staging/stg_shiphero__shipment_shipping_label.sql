-- stg_shiphero__shipment_shipping_label
-- Thin wrapper over raw `shipment_shipping_label`. One row per label (package).
--
-- `cost` is what the carrier label cost, as a string; cast here. A label that was
-- voided and refunded by the carrier still has a row, so is_refunded is
-- kept and core excludes refunded labels from shipping cost.

SELECT
    'account_1'                                       AS shiphero_account,
    CAST(id AS STRING)                                AS shipping_label_id,
    CAST(shipment_id AS STRING)                       AS shipment_id,
    CAST(order_id AS STRING)                          AS order_id,
    CAST(warehouse_id AS STRING)                      AS warehouse_id,
    NULLIF(TRIM(CAST(carrier AS STRING)), '')         AS carrier,
    NULLIF(TRIM(CAST(shipping_method AS STRING)), '') AS shipping_method,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))   AS status,
    SAFE_CAST(cost AS NUMERIC)                        AS label_cost,
    COALESCE(CAST(refunded AS BOOL), FALSE)           AS is_refunded,
    CAST(created_date AS TIMESTAMP)                   AS created_at
FROM {{ source('shiphero', 'shipment_shipping_label') }}
