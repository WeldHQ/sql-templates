-- staging.shiphero.shipment
-- Thin wrapper over raw `shipment`. One row per shipment: one or more packages
-- sent for an order from one warehouse. An order shipped in two goes has two.
--
-- created_date is when the shipment was created, i.e. when the order was packed
-- and labelled. That is the "shipped" moment ShipHero reports on.
--
-- STATUS FLAGS LAG. The connector reads shipments by creation date, so flags that
-- change later (delivered, picked_up) only refresh when that period is re-synced.
-- Do not build delivery-time reporting on them.

SELECT
    'account_1'                                 AS shiphero_account,
    CAST(id AS STRING)                          AS shipment_id,
    CAST(order_id AS STRING)                    AS order_id,
    CAST(warehouse_id AS STRING)                AS warehouse_id,
    CAST(user_id AS STRING)                     AS user_id,
    CAST(total_packages AS INT64)               AS total_packages,
    CAST(dropshipment AS BOOL)                  AS is_dropshipment,
    CAST(shipped_off_shiphero AS BOOL)          AS is_shipped_off_shiphero,
    CAST(created_date AS TIMESTAMP)             AS shipped_at
FROM {{raw.shiphero.shipment}}
