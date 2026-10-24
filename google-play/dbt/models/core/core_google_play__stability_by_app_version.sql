-- core_google_play__stability_by_app_version
-- Crashes and ANRs ("app not responding") per app version, against how many active
-- devices run that version, so a bad release stands out against its install base.
--
-- Grain: one row per day x package x app version code.
-- Depends on: staging.google_play.crashes_by_app_version,
--             staging.google_play.installs_by_app_version
--
-- crashes_per_1000_active_installs is a ratio of the day's crashes to the devices
-- with that version installed and active in the last 30 days. It is a trend
-- indicator for comparing versions, not Android vitals' crash rate, which Google
-- computes per daily active user and does not export.

SELECT
    COALESCE(c.date_day, i.date_day)                    AS date_day,
    COALESCE(c.package_name, i.package_name)            AS package_name,
    COALESCE(c.app_version_code, i.app_version_code)    AS app_version_code,
    COALESCE(c.daily_crashes, 0)                        AS daily_crashes,
    COALESCE(c.daily_anrs, 0)                           AS daily_anrs,
    i.installs_on_active_devices,
    i.daily_device_upgrades,
    ROUND(SAFE_DIVIDE(c.daily_crashes, NULLIF(i.installs_on_active_devices, 0)) * 1000, 3)
                                                        AS crashes_per_1000_active_installs,
    ROUND(SAFE_DIVIDE(c.daily_anrs, NULLIF(i.installs_on_active_devices, 0)) * 1000, 3)
                                                        AS anrs_per_1000_active_installs
FROM {{ ref('stg_google_play__crashes_by_app_version') }} c
FULL OUTER JOIN {{ ref('stg_google_play__installs_by_app_version') }} i
  ON  i.date_day         = c.date_day
  AND i.package_name     = c.package_name
  AND i.app_version_code = c.app_version_code
