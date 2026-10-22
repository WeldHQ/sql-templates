-- staging.app_store_connect.sessions
-- Thin wrapper over raw `app_sessions` (Apple's "App Sessions Detailed" analytics
-- report). Casts, renames, de-duplicates on the connector's primary key.
-- Join columns that Apple leaves empty become 'unknown', so the core models can
-- join reports on them without losing rows to NULL keys.
--
-- Grain: day x app x app version x device x OS version x source type x source info
-- x campaign x page type x territory.
--
-- Opted-in users only, rows under five users suppressed. total_session_seconds is
-- the summed length of all sessions in the row, in seconds, per Apple's docs.

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
    CAST(sessions AS INT64)                 AS sessions,
    CAST(total_session_duration AS INT64)   AS total_session_seconds,
    CAST(unique_devices AS INT64)           AS unique_devices
FROM {{raw.app_store_connect.app_sessions}}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, app_apple_identifier, app_version, device, platform_version,
                 source_type, source_info, campaign, page_type, territory
    ORDER BY _weld_synced DESC
) = 1
