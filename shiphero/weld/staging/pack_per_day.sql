-- staging.shiphero.pack_per_day
-- Thin wrapper over raw `pack_per_day`, ShipHero's pack log. One row per packed
-- shipment, with the packer and the number of items in it.

SELECT
    'account_1'                                       AS shiphero_account,
    CAST(id AS STRING)                                AS pack_id,
    CAST(warehouse_id AS STRING)                      AS warehouse_id,
    CAST(user_id AS STRING)                           AS user_id,
    NULLIF(TRIM(CONCAT(COALESCE(CAST(user_first_name AS STRING), ''), ' ',
                       COALESCE(CAST(user_last_name AS STRING), ''))), '') AS user_name,
    CAST(order_id AS STRING)                          AS order_id,
    CAST(shipment_id AS STRING)                       AS shipment_id,
    CAST(total_items AS INT64)                        AS total_items,
    CAST(unique_items AS INT64)                       AS unique_items,
    CAST(created_at AS TIMESTAMP)                     AS packed_at
FROM {{raw.shiphero.pack_per_day}}
