-- staging.calendly.scheduled_event
-- Thin wrapper over raw `list_events`, Calendly's scheduled events. One row per
-- meeting on the calendar, active or canceled. Casts, renames, unpacks the JSON
-- objects. No business logic.
--
-- DEDUPED ON uri. Scheduled events are synced once per organisation member,
-- so a meeting with two hosts (a collective or round robin pooled event)
-- arrives once for each host. Without the QUALIFY every multi-host meeting would be
-- counted twice in every report.
--
-- EVENT TYPE: Calendly's event type list is not synced, only the event type's URI
-- and the scheduled event's `name`, which is the event type name at the time of
-- booking. A renamed event type therefore shows up under two names across history;
-- core keys on event_type_uri and picks the most recent name.
--
-- Timestamps are UTC. Calendly returns ISO 8601 strings, cast here.
--
-- Single Calendly organisation. To add another, UNION ALL a second block below
-- pointing at that connector with a different calendly_account label. Keep it in
-- staging so the core models never have to know how many accounts there are.

SELECT
    'account_1'                                               AS calendly_account,
    CAST(uri AS STRING)                                       AS event_uri,
    NULLIF(TRIM(CAST(name AS STRING)), '')                    AS event_name,
    NULLIF(CAST(event_type AS STRING), '')                    AS event_type_uri,
    LOWER(CAST(status AS STRING))                             AS status,
    SAFE_CAST(start_time AS TIMESTAMP)                        AS start_time,
    SAFE_CAST(end_time AS TIMESTAMP)                          AS end_time,
    -- created_at is when the meeting was booked (the first invitee's booking for a
    -- group event).
    SAFE_CAST(created_at AS TIMESTAMP)                        AS created_at,
    SAFE_CAST(updated_at AS TIMESTAMP)                        AS updated_at,

    -- location.type: zoom_conference, google_conference, physical,
    -- outbound_call, inbound_call, custom and so on.
    JSON_VALUE(location, '$.type')                            AS location_type,

    SAFE_CAST(JSON_VALUE(invitees_counter, '$.total')  AS INT64) AS invitees_total,
    SAFE_CAST(JSON_VALUE(invitees_counter, '$.active') AS INT64) AS invitees_active,
    SAFE_CAST(JSON_VALUE(invitees_counter, '$.limit')  AS INT64) AS invitees_limit,

    -- Populated only on canceled events. canceler_type is 'host' or 'invitee'.
    JSON_VALUE(cancellation, '$.canceler_type')               AS canceler_type,
    JSON_VALUE(cancellation, '$.canceled_by')                 AS canceled_by,
    NULLIF(JSON_VALUE(cancellation, '$.reason'), '')          AS cancel_reason,
    SAFE_CAST(JSON_VALUE(cancellation, '$.created_at') AS TIMESTAMP) AS canceled_at,

    -- The host list, kept as JSON and unpacked one row per host by
    -- staging.calendly.scheduled_event_host.
    CAST(event_memberships AS STRING)                         AS event_memberships_json
FROM {{raw.calendly.list_events}}
WHERE uri IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY uri ORDER BY SAFE_CAST(updated_at AS TIMESTAMP) DESC) = 1
