-- stg_mixpanel_source__events
-- Thin wrapper over raw `events`: one row per tracked Mixpanel event, keeping the columns
-- every report needs. Casts `time` to a timestamp and removes duplicates the way Mixpanel
-- does.
--
-- Grain: one event, after de-duplication (event_hash identifies the surviving row).
-- The events table has one column per event property in your project, so its width is
-- yours, not fixed. This model reads the columns that are always present
-- (`event_hash`, `event_name`, `distinct_id`, `time`) plus `insert_id`, the snake_cased
-- `$insert_id` that Mixpanel's SDKs attach to every event. Add your own properties here
-- (plan, country, platform) if you want them as report dimensions.
--
-- Duplicates: Mixpanel treats events with the same name, distinct_id, time (to the second)
-- and $insert_id as one event and shows a single copy in its reports. A client retry
-- sends the same event again with different processing metadata, so
-- `event_hash`, which hashes the whole event, differs between the copies and cannot catch
-- it. This model applies Mixpanel's rule instead. Events without an insert_id fall back to
-- `event_hash`, which still removes rows that arrived twice. If your table has no
-- `insert_id` column at all (no SDK in your project sends it), replace `insert_id` below
-- with NULL.

SELECT
    CAST(event_hash AS STRING)                  AS event_hash,
    CAST(insert_id AS STRING)                   AS insert_id,
    CAST(event_name AS STRING)                  AS event_name,
    CAST(distinct_id AS STRING)                 AS distinct_id,
    TIMESTAMP_SECONDS(CAST(time AS INT64))      AS event_at
FROM {{ source('mixpanel_source', 'events') }}
WHERE time IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY
        event_name,
        distinct_id,
        CAST(time AS INT64),
        COALESCE(CAST(insert_id AS STRING), CAST(event_hash AS STRING))
    ORDER BY _weld_synced DESC, event_hash
) = 1
