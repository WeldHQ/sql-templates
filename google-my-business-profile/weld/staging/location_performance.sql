-- staging.google_my_business_profile.location_performance
-- Thin wrapper over raw `location_performance_daily`, the Business Profile
-- Performance API daily metrics. Casts and renames. No other logic.
--
-- Grain: location x date x metric (long format: one row per metric per day).
-- The raw table has one row per (location_id, date, metric), and the last three
-- days are re-read on each sync, so rows do not repeat. Google omits days with no value for a
-- metric rather than sending zero.

SELECT
    CAST(location_id AS STRING)          AS location_id,
    SAFE_CAST(date AS DATE)              AS date_day,
    UPPER(CAST(metric AS STRING))        AS metric,
    CAST(COALESCE(value, 0) AS INT64)    AS value
FROM {{raw.google_my_business_profile.location_performance_daily}}
