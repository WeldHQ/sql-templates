-- core.cargoson.carrier_costs_by_month
-- Shipments, freight spend, weight moved and delivery performance per carrier
-- and service, per month.
-- Grain: month x cargoson_account x carrier_name x service_name x freight_currency.
-- Currency: freight_currency is in the grain, so a carrier billed in two
-- currencies returns two rows. Never sum freight_cost across currencies.
-- Depends on: core.cargoson.shipments
--
-- A shipment lands in the month of shipment_date: collection, falling back to
-- the booking date. Cancelled shipments are counted in cancelled_shipments and
-- excluded from everything else.
--
-- RATES ARE RATIOS OF SUMS. freight_cost_per_kg is total cost over total kg of
-- the shipments that have BOTH a price and a metric weight, so one 2 kg parcel
-- does not count as much as a 20 tonne truck. on_time_rate divides by the
-- shipments where on-time could be judged, not by every shipment.
--
-- Built on a month spine per carrier and service, from the first month the
-- combination appears to the current month (or its latest planned month), so a carrier with a quiet month
-- returns zeros instead of vanishing from a trend line.

WITH shipments AS (
    SELECT
        *,
        DATE_TRUNC(shipment_date, MONTH) AS month,
        COALESCE(carrier_name, '(unknown carrier)') AS carrier_label,
        COALESCE(service_name, '(unknown service)') AS service_label
    FROM {{core.cargoson.shipments}}
    WHERE shipment_date IS NOT NULL
),

series AS (
    SELECT
        cargoson_account,
        carrier_label,
        service_label,
        freight_currency,
        MIN(month) AS first_month,
        MAX(month) AS last_month
    FROM shipments
    GROUP BY 1, 2, 3, 4
),

spine AS (
    SELECT
        s.cargoson_account,
        s.carrier_label,
        s.service_label,
        s.freight_currency,
        m AS month
    FROM series s
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(
        s.first_month,
        -- To the current month, or further when a booking is already planned for
        -- a later collection, so future shipments are not cut off.
        GREATEST(s.last_month, DATE_TRUNC(CURRENT_DATE(), MONTH)),
        INTERVAL 1 MONTH
    )) AS m
),

monthly AS (
    SELECT
        cargoson_account,
        carrier_label,
        service_label,
        freight_currency,
        month,
        COUNTIF(NOT is_cancelled)                                   AS shipments,
        COUNTIF(is_cancelled)                                       AS cancelled_shipments,
        COUNTIF(is_delivered)                                       AS delivered_shipments,
        SUM(freight_cost)                                           AS freight_cost,
        SUM(IF(NOT is_cancelled, weight_kg, NULL))                  AS weight_kg,
        SUM(IF(NOT is_cancelled, total_cbm, NULL))                  AS cbm,
        SUM(IF(NOT is_cancelled, packages, NULL))                   AS packages,
        SUM(IF(freight_cost IS NOT NULL AND weight_kg > 0, freight_cost, NULL)) AS priced_cost,
        SUM(IF(freight_cost IS NOT NULL AND weight_kg > 0, weight_kg, NULL))    AS priced_weight_kg,
        SUM(IF(NOT is_cancelled, co2e_kg, NULL))                    AS co2e_kg,
        SUM(IF(NOT is_cancelled, transit_days, NULL))               AS transit_days_total,
        COUNTIF(NOT is_cancelled AND transit_days IS NOT NULL)      AS shipments_with_transit,
        COUNTIF(is_on_time)                                         AS on_time_shipments,
        COUNTIF(is_on_time IS NOT NULL)                             AS shipments_judged_on_time
    FROM shipments
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    s.month,
    s.cargoson_account,
    s.carrier_label                       AS carrier_name,
    s.service_label                       AS service_name,
    s.freight_currency,
    COALESCE(m.shipments, 0)              AS shipments,
    COALESCE(m.cancelled_shipments, 0)    AS cancelled_shipments,
    COALESCE(m.delivered_shipments, 0)    AS delivered_shipments,
    COALESCE(m.freight_cost, 0)           AS freight_cost,
    COALESCE(m.weight_kg, 0)              AS weight_kg,
    COALESCE(m.cbm, 0)                    AS cbm,
    COALESCE(m.packages, 0)               AS packages,
    COALESCE(m.co2e_kg, 0)                AS co2e_kg,
    SAFE_DIVIDE(m.freight_cost, m.shipments)          AS freight_cost_per_shipment,
    SAFE_DIVIDE(m.priced_cost, m.priced_weight_kg)    AS freight_cost_per_kg,
    SAFE_DIVIDE(m.transit_days_total, m.shipments_with_transit) AS avg_transit_days,
    COALESCE(m.on_time_shipments, 0)                  AS on_time_shipments,
    COALESCE(m.shipments_judged_on_time, 0)           AS shipments_judged_on_time,
    SAFE_DIVIDE(m.on_time_shipments, m.shipments_judged_on_time) AS on_time_rate
FROM spine s
LEFT JOIN monthly m
    ON  m.cargoson_account = s.cargoson_account
    AND m.carrier_label    = s.carrier_label
    AND m.service_label    = s.service_label
    AND m.freight_currency IS NOT DISTINCT FROM s.freight_currency
    AND m.month            = s.month
