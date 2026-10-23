-- stg_app_store_connect__crashes
-- Thin wrapper over raw `app_crashes` (Apple's "App Crashes Detailed" analytics
-- report). Casts, renames, keeps the latest row per key.
-- Join columns that Apple leaves empty become 'unknown', so the core models can
-- join reports on them without losing rows to NULL keys.
--
-- Grain: day x app x app version x device x OS version.
-- Apple's crash report has no territory, source or page breakdown. The raw table
-- has those columns too, but they arrive empty on crash rows, so
-- crashes can only be joined to other reports on day, app, version and device.
--
-- Opted-in users only. Crash counts here are for reporting trends; Xcode Organizer
-- and your crash reporter remain the place to debug individual crashes.

SELECT
    CAST(date AS DATE)                      AS date_day,
    CAST(app_apple_identifier AS STRING)    AS app_apple_id,
    CAST(app_name AS STRING)                AS app_name,
    COALESCE(CAST(app_version AS STRING), 'unknown')  AS app_version,
    COALESCE(CAST(device AS STRING), 'unknown')       AS device,
    CAST(platform_version AS STRING)        AS platform_version,
    COALESCE(CAST(source_type AS STRING), 'unknown')  AS source_type,
    CAST(page_type AS STRING)               AS page_type,
    COALESCE(UPPER(CAST(territory AS STRING)), 'unknown') AS territory,
    CAST(crashes AS INT64)                  AS crashes
FROM {{ source('app_store_connect', 'app_crashes') }}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, app_apple_identifier, app_version, device, platform_version,
                 source_type, source_info, campaign, page_type, territory
    ORDER BY _weld_synced DESC
) = 1
