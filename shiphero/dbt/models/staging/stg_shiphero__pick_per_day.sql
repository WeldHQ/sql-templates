-- stg_shiphero__pick_per_day
-- Thin wrapper over raw `pick_per_day`, ShipHero's pick log. One row per pick
-- event: a picker taking a SKU from a bin for an order.
--
-- `quantity` is what the pick asked for, `picked_quantity` what was actually
-- picked; productivity counts the second.

SELECT
    'account_1'                                       AS shiphero_account,
    CAST(id AS STRING)                                AS pick_id,
    CAST(warehouse_id AS STRING)                      AS warehouse_id,
    CAST(user_id AS STRING)                           AS user_id,
    NULLIF(TRIM(CONCAT(COALESCE(CAST(user_first_name AS STRING), ''), ' ',
                       COALESCE(CAST(user_last_name AS STRING), ''))), '') AS user_name,
    CAST(order_id AS STRING)                          AS order_id,
    NULLIF(TRIM(CAST(sku AS STRING)), '')             AS sku,
    NULLIF(TRIM(CAST(pick_type AS STRING)), '')       AS pick_type,
    CAST(quantity AS INT64)                           AS quantity_requested,
    CAST(picked_quantity AS INT64)                    AS quantity_picked,
    CAST(created_at AS TIMESTAMP)                     AS picked_at
FROM {{ source('shiphero', 'pick_per_day') }}
