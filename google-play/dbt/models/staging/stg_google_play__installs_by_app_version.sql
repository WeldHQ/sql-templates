-- stg_google_play__installs_by_app_version
-- Thin wrapper over raw `stats_installs_app_version`: the installs export, app
-- version breakdown. Casts, renames, keeps the latest version of each row.
--
-- Grain: one row per day x package x app version code.

SELECT
    CAST(date AS DATE)                              AS date_day,
    CAST(package_name AS STRING)                    AS package_name,
    CAST(app_version_code AS STRING)                AS app_version_code,
    CAST(installs_on_active_devices AS INT64)       AS installs_on_active_devices,
    CAST(daily_device_installs AS INT64)            AS daily_device_installs,
    CAST(daily_device_upgrades AS INT64)            AS daily_device_upgrades
FROM {{ source('google_play', 'stats_installs_app_version') }}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, package_name, app_version_code
    ORDER BY file_last_modified DESC, _weld_synced DESC
) = 1
