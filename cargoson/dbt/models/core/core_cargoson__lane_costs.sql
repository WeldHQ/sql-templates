-- core_cargoson__lane_costs
-- What it costs to move goods on each lane, by carrier: the table you take into
-- a freight tender.
-- Grain: cargoson_account x collection_country x delivery_country x carrier_name
--        x freight_type x freight_currency. All time, with the date range shown.
-- Depends on: core.cargoson.shipments
--
-- Cancelled shipments are excluded. A lane is country to country; Cargoson
-- syncs city and postcode too (see core.cargoson.shipments) if you need to cut
-- finer, but at postcode level most lanes have too few shipments for an average
-- to mean anything.
--
-- freight_cost_per_kg is a ratio of sums over the shipments that have both a
-- price and a metric weight. shipments_last_90_days is there so a lane that
-- looked cheap three years ago and has not been used since does not set the
-- benchmark.

SELECT
    cargoson_account,
    collection_country,
    delivery_country,
    lane,
    COALESCE(carrier_name, '(unknown carrier)') AS carrier_name,
    freight_type,
    freight_currency,
    MIN(shipment_date)                                  AS first_shipment_date,
    MAX(shipment_date)                                  AS last_shipment_date,
    COUNT(*)                                            AS shipments,
    COUNTIF(shipment_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)) AS shipments_last_90_days,
    SUM(freight_cost)                                   AS freight_cost,
    SUM(weight_kg)                                      AS weight_kg,
    SAFE_DIVIDE(SUM(freight_cost), COUNTIF(freight_cost IS NOT NULL)) AS avg_freight_cost_per_shipment,
    SAFE_DIVIDE(
        SUM(IF(freight_cost IS NOT NULL AND weight_kg > 0, freight_cost, NULL)),
        SUM(IF(freight_cost IS NOT NULL AND weight_kg > 0, weight_kg, NULL))
    )                                                   AS freight_cost_per_kg,
    AVG(transit_days)                                   AS avg_transit_days,
    SAFE_DIVIDE(COUNTIF(is_on_time), COUNTIF(is_on_time IS NOT NULL)) AS on_time_rate
FROM {{ ref('core_cargoson__shipments') }}
WHERE NOT is_cancelled
GROUP BY 1, 2, 3, 4, 5, 6, 7
