-- stg_google_play__crashes_by_app_version
-- Thin wrapper over raw `stats_crashes_app_version`: the crashes export, app
-- version breakdown. Casts, renames, keeps the latest version of each row.
--
-- Grain: one row per day x package x app version code.
--
-- These are the crash and ANR counts Play Console exports to Cloud Storage. Android
-- vitals' crash rate and user-perceived ANR rate are computed differently (per
-- daily active user) and are not in this export.

SELECT
    CAST(date AS DATE)                  AS date_day,
    CAST(package_name AS STRING)        AS package_name,
    CAST(app_version_code AS STRING)    AS app_version_code,
    CAST(daily_crashes AS INT64)        AS daily_crashes,
    CAST(daily_anrs AS INT64)           AS daily_anrs
FROM {{ source('google_play', 'stats_crashes_app_version') }}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, package_name, app_version_code
    ORDER BY file_last_modified DESC, _weld_synced DESC
) = 1
