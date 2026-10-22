-- carrier_costs_by_month holds every shipment's freight cost exactly once.
--
-- Summed over all months, carriers and services, freight cost and shipment count
-- must equal the same totals taken from shipments. A gap means the month spine
-- dropped or duplicated rows, usually after a grain change on one side of its
-- join and not the other.

WITH shipments AS (
    SELECT
        cargoson_account,
        freight_currency,
        COUNTIF(NOT is_cancelled)        AS shipments,
        COALESCE(SUM(freight_cost), 0)   AS freight_cost
    FROM {{ ref('core_cargoson__shipments') }}
    WHERE shipment_date IS NOT NULL
    GROUP BY 1, 2
),

monthly AS (
    SELECT
        cargoson_account,
        freight_currency,
        SUM(shipments)     AS shipments,
        SUM(freight_cost)  AS freight_cost
    FROM {{ ref('core_cargoson__carrier_costs_by_month') }}
    GROUP BY 1, 2
)

SELECT
    s.cargoson_account,
    s.freight_currency,
    s.shipments,
    m.shipments    AS monthly_shipments,
    s.freight_cost,
    m.freight_cost AS monthly_freight_cost
FROM shipments s
LEFT JOIN monthly m
    ON  m.cargoson_account = s.cargoson_account
    AND m.freight_currency IS NOT DISTINCT FROM s.freight_currency
WHERE s.shipments <> COALESCE(m.shipments, 0)
   OR ABS(s.freight_cost - COALESCE(m.freight_cost, 0)) > 0.01
