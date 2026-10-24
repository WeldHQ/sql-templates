-- staging.calendly.scheduled_event_host
-- One row per scheduled event x host, unpacked from the `event_memberships` array
-- on the scheduled event. A one-on-one meeting has one host; a collective event
-- has several.
--
-- Reads the deduped staging.calendly.scheduled_event rather than raw, so a
-- multi-host meeting (which arrives once per host in raw) is unpacked once.

SELECT
    e.calendly_account,
    e.event_uri,
    JSON_VALUE(m, '$.user')                        AS host_user_uri,
    LOWER(JSON_VALUE(m, '$.user_email'))           AS host_email,
    JSON_VALUE(m, '$.user_name')                   AS host_name
FROM {{staging.calendly.scheduled_event}} e,
    UNNEST(JSON_QUERY_ARRAY(e.event_memberships_json)) AS m
WHERE JSON_VALUE(m, '$.user') IS NOT NULL
