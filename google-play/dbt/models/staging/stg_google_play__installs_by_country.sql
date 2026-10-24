-- stg_google_play__installs_by_country
-- Thin wrapper over raw `stats_installs_country`: Play Console's monthly installs
-- export, country breakdown. Casts, renames, keeps the latest version of each row.
--
-- Grain: one row per day x package x country.
--
-- Google rewrites the current month's file every day and it is read again on each
-- sync, so a recent day can arrive more than once. Only the newest read is kept.

SELECT
    CAST(date AS DATE)                              AS date_day,
    CAST(package_name AS STRING)                    AS package_name,
    UPPER(CAST(country AS STRING))                  AS country,
    CAST(daily_user_installs AS INT64)              AS daily_user_installs,
    CAST(daily_user_uninstalls AS INT64)            AS daily_user_uninstalls,
    CAST(daily_device_installs AS INT64)            AS daily_device_installs,
    CAST(daily_device_uninstalls AS INT64)          AS daily_device_uninstalls,
    CAST(daily_device_upgrades AS INT64)            AS daily_device_upgrades,
    -- Point-in-time levels, not daily flows: never sum these across days.
    CAST(installs_on_active_devices AS INT64)       AS installs_on_active_devices,
    CAST(total_user_installs AS INT64)              AS total_user_installs
FROM {{ source('google_play', 'stats_installs_country') }}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, package_name, country
    ORDER BY file_last_modified DESC, _weld_synced DESC
) = 1
