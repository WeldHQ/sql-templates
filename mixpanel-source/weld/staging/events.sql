-- staging.mixpanel_source.events
-- Thin wrapper over raw `events`: one row per tracked Mixpanel event, keeping the columns
-- every report needs. Casts `time` to a timestamp and de-duplicates.
--
-- Grain: event_hash (one event).
-- The events table has one column per event property in your project, so its width is
-- yours, not fixed. This model reads only the columns the connector always writes:
-- `event_hash`, `event_name`, `distinct_id` and `time`. Add your own properties here
-- (plan, country, platform) if you want them as report dimensions.
--
-- `time` is Mixpanel's event time in whole seconds. The stream appends, and `event_hash`
-- is a hash of the whole event, so an event delivered twice has the same hash and is kept
-- once.

SELECT
    CAST(event_hash AS STRING)                  AS event_hash,
    CAST(event_name AS STRING)                  AS event_name,
    CAST(distinct_id AS STRING)                 AS distinct_id,
    TIMESTAMP_SECONDS(CAST(time AS INT64))      AS event_at
FROM {{raw.mixpanel_source.events}}
WHERE time IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_hash ORDER BY _weld_synced DESC) = 1
