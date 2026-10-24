-- One row per scheduled event. The raw stream repeats a multi-host meeting once per
-- host; if this fails, the dedupe in stg_calendly__scheduled_event has been lost and
-- every group meeting is being counted twice.

SELECT calendly_account, event_uri, COUNT(*) AS rows_per_event
FROM {{ ref('core_calendly__scheduled_events') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
