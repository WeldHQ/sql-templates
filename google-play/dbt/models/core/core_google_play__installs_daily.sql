-- core_google_play__installs_daily
-- Installs and uninstalls per app and country, the Statistics page of Play Console
-- with the user and device metrics side by side.
--
-- Grain: one row per day x package x country.
-- Depends on: staging.google_play.installs_by_country
--
-- USERS VS. DEVICES. A user installs once per Google account however many devices
-- they put the app on; a device install counts each device. Play Console's
-- "acquisitions" are the user numbers. Pick one and stay with it.
--
-- `installs_on_active_devices` is a level (how many devices have the app and were
-- active in the last 30 days), not a flow. Sum the daily_ columns over a period;
-- for the level take the last day of the period, never the sum.
--
-- Dates are as Play Console exports them. Google does not state a time zone for
-- the statistics files; Play Console shows them in Pacific Time.

SELECT
    date_day,
    package_name,
    country,
    daily_user_installs,
    daily_user_uninstalls,
    daily_user_installs - daily_user_uninstalls         AS net_user_installs,
    daily_device_installs,
    daily_device_uninstalls,
    daily_device_upgrades,
    installs_on_active_devices,
    ROUND(SAFE_DIVIDE(daily_user_uninstalls, NULLIF(daily_user_installs, 0)), 4) AS uninstalls_per_install
FROM {{ ref('stg_google_play__installs_by_country') }}
