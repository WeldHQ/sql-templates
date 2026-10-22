-- staging.app_store_connect.store_engagement
-- Thin wrapper over raw `app_store_engagement` (Apple's "App Store Discovery and
-- Engagement Detailed" analytics report): impressions, product page views and taps
-- on the App Store itself. Casts, renames, de-duplicates on the connector's
-- primary key. Join columns that Apple leaves empty become 'unknown', so the
-- core models can join reports on them without losing rows to NULL keys.
--
-- Grain: day x app x event x engagement type x device x OS version x source type x
-- source info x page type x territory.
--
-- event is 'Impression', 'Page view' or 'Tap'. engagement_type is the action taken
-- ('Get', 'Redownload', 'Open', ...); the connector writes 'none' when Apple leaves
-- it empty. unique_counts is distinct users within the row and cannot be summed
-- across rows.

SELECT
    CAST(date AS DATE)                      AS date_day,
    CAST(app_apple_identifier AS STRING)    AS app_apple_id,
    CAST(app_name AS STRING)                AS app_name,
    CAST(event AS STRING)                   AS event,
    CAST(engagement_type AS STRING)         AS engagement_type,
    COALESCE(CAST(device AS STRING), 'unknown')       AS device,
    CAST(platform_version AS STRING)        AS platform_version,
    COALESCE(CAST(source_type AS STRING), 'unknown')  AS source_type,
    CAST(source_info AS STRING)             AS source_info,
    CAST(page_type AS STRING)               AS page_type,
    COALESCE(UPPER(CAST(territory AS STRING)), 'unknown') AS territory,
    CAST(counts AS INT64)                   AS event_count,
    CAST(unique_counts AS INT64)            AS unique_users
FROM {{raw.app_store_connect.app_store_engagement}}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY date, app_apple_identifier, device, event, source_type, platform_version,
                 territory, page_type, engagement_type, source_info
    ORDER BY _weld_synced DESC
) = 1
