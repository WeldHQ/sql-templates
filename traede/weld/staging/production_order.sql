-- staging.traede.production_order
-- Thin wrapper over raw `production_order`. One row per production order, the
-- purchase order a brand places with its supplier or factory.
--
-- `expected_*` dates are the current plan; `original_expected_*` are what was
-- promised when the order was placed. The gap between them is the supplier's
-- slippage and is computed in core.

SELECT
    'account_1'                                                   AS traede_account,
    CAST(id AS STRING)                                            AS production_order_id,
    NULLIF(TRIM(CAST(production_order_number AS STRING)), '')     AS production_order_number,
    -- in_production, partially_sent, sent, partially_received, received,
    -- partially_booked, booked, closed (and open as the default).
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))               AS status,
    CAST(supplier_id AS STRING)                                   AS supplier_id,
    DATE(CAST(expected_departure AS TIMESTAMP))                   AS expected_departure_date,
    DATE(CAST(original_expected_departure AS TIMESTAMP))          AS original_expected_departure_date,
    DATE(CAST(expected_arrival AS TIMESTAMP))                     AS expected_arrival_date,
    DATE(CAST(original_expected_arrival AS TIMESTAMP))            AS original_expected_arrival_date,
    CAST(created_at AS TIMESTAMP)                                 AS created_at,
    CAST(updated_at AS TIMESTAMP)                                 AS updated_at
FROM {{raw.traede.production_order}}
