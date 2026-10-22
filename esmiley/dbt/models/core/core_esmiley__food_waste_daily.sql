-- core_esmiley__food_waste_daily
-- Food waste per day, account and registration point: weight, value and CO2.
-- The figures behind eSmiley's dashboard, as a table.
-- Grain: registration date x account x registration point.
--
-- Dates are the UTC date of the registration time. Cost is in the currency on the
-- registration; group by currency before summing across accounts. See
-- staging.esmiley.registration for how weight, cost and CO2 are converted.

SELECT
    r.registration_date,
    r.account_id,
    a.account_name,
    r.registration_point_id,
    COALESCE(t.registration_point_name, ANY_VALUE(r.registration_point_name)) AS registration_point_name,
    t.area,
    t.path,
    r.currency,
    COUNT(*)                         AS registrations,
    ROUND(SUM(r.waste_kg), 3)        AS waste_kg,
    ROUND(SUM(r.cost), 2)            AS cost,
    ROUND(SUM(r.co2_kg), 3)          AS co2_kg
FROM {{ ref('stg_esmiley__registration') }} r
LEFT JOIN {{ ref('core_esmiley__registration_point_tree') }} t USING (registration_point_id)
LEFT JOIN {{ ref('stg_esmiley__account') }} a ON a.account_id = r.account_id
GROUP BY r.registration_date, r.account_id, a.account_name, r.registration_point_id,
         t.registration_point_name, t.area, t.path, r.currency
