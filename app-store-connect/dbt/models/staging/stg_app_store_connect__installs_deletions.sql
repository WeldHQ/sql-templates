-- stg_app_store_connect__installs_deletions
-- Thin wrapper over raw `app_installs_deletions` (Apple's "App Store Installation
-- and Deletion Detailed" analytics report). Casts, renames, de-duplicates on the
-- connector's primary key.
-- Join columns that Apple leaves empty become 'unknown', so the core models can
-- join reports on them without losing rows to NULL keys.
--
-- Grain: day x app x event x download type x app version x device x OS version x
-- source type x source info x campaign x page type x territory.
--
-- Counts cover only users who agreed to share analytics data with developers, and
-- Apple drops any row with fewer than five users. These are smaller than the
-- download totals in the Sales report, by design.

SELECT
    CAST(date AS DATE)                      AS date_day,
    CAST(app_apple_identifier AS STRING)    AS app_apple_id,
    CAST(app_name AS STRING)                AS app_name,
    CAST(event AS STRING)                   AS event,           -- 'Install' or 'Delete'
    CAST(download_type AS STRING)           AS download_type,   -- 'First-time download', 'Redownload', 'Manual update', ...
    COALESCE(CAST(app_version AS STRING), 'unknown')  AS app_version,
    COALESCE(CAST(device AS STRING), 'unknown')       AS device,
    CAST(platform_version AS STRING)        AS platform_version,
    COALESCE(CAST(source_type AS STRING), 'unknown')  AS source_type,
    CAST(source_info AS STRING)             AS source_info,
    CAST(campaign AS STRING)                AS campaign,
    CAST(page_type AS STRING)               AS page_type,
    COALESCE(UPPER(CAST(territory AS STRING)), 'unknown') AS territory,
    CAST(counts AS INT64)                   AS event_count,
    CAST(unique_devices AS INT64)           AS unique_devices
FROM {{ source('app_store_connect', 'app_installs_deletions') }}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, app_apple_identifier, event, download_type, app_version, device,
                 platform_version, source_type, source_info, campaign, page_type, territory
    ORDER BY _weld_synced DESC
) = 1
