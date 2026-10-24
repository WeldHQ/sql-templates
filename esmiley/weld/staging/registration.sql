-- staging.esmiley.registration
-- Thin wrapper over raw `registration`. One row per food waste registration (one
-- weighing), deleted registrations removed.
--
-- Units, as integers from eSmiley:
--   amount   the weight, in the unit named in `unit` (grams in practice). It is
--            converted to kilograms here; a unit of "kg" is taken as is.
--   cost     the value of the waste in the minor unit of `currency` (cents, øre),
--            divided by 100 here.
--   co2_per_kg  the CO2 factor of the registration point, read as grams of CO2e
--            per kg of waste, so co2_kg = waste_kg x co2_per_kg / 1000.
-- eSmiley does not publish these units in a public API reference. Compare one
-- registration with the eSmiley app before relying on cost and CO2; the raw
-- integers are kept alongside so a different reading is a one-line change.

SELECT
    CAST(id AS INT64)                               AS registration_id,
    CAST(account_id AS INT64)                       AS account_id,
    CAST(registration_point_id AS INT64)            AS registration_point_id,
    CAST(registration_point_name AS STRING)         AS registration_point_name,
    CAST(user_id AS INT64)                          AS user_id,
    CAST(date AS TIMESTAMP)                         AS registered_at,
    DATE(CAST(date AS TIMESTAMP))                   AS registration_date,
    LOWER(CAST(unit AS STRING))                     AS unit,
    UPPER(CAST(currency AS STRING))                 AS currency,
    CAST(amount AS INT64)                           AS amount_raw,
    CAST(cost AS INT64)                             AS cost_raw,
    CAST(co2_per_kg AS INT64)                       AS co2_per_kg_raw,
    IF(LOWER(CAST(unit AS STRING)) = 'kg', CAST(amount AS FLOAT64), CAST(amount AS FLOAT64) / 1000) AS waste_kg,
    CAST(cost AS FLOAT64) / 100                     AS cost,
    IF(LOWER(CAST(unit AS STRING)) = 'kg', CAST(amount AS FLOAT64), CAST(amount AS FLOAT64) / 1000)
        * CAST(co2_per_kg AS FLOAT64) / 1000        AS co2_kg,
    COALESCE(scale, FALSE)                          AS weighed_on_scale,
    CAST(comment AS STRING)                         AS comment
FROM {{raw.esmiley.registration}}
WHERE id IS NOT NULL
  AND deleted_at IS NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS INT64)
    ORDER BY CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
