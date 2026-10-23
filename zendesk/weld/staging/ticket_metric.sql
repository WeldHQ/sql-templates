-- staging.zendesk.ticket_metric
-- Thin wrapper over raw `ticket_metric`: Zendesk's own per-ticket metrics, one
-- row per ticket. Casts and renames only.
--
-- These are synced alongside each ticket, so the table refreshes
-- whenever the ticket changes. Every duration is in MINUTES and comes in two
-- flavours: _calendar (wall clock) and _business (inside the schedule applied to
-- the ticket). These are the same numbers Zendesk Explore uses for "First reply
-- time", "Full resolution time" and "Requester wait time", so nothing is
-- recomputed from comments.
--
-- solved_at is the LATEST solve. A ticket that was solved, reopened and solved
-- again carries only the second timestamp; `reopens` tells you it happened.

SELECT
    'account_1'                                              AS zendesk_account,
    CAST(ticket_id AS STRING)                                AS ticket_id,
    CAST(created_at AS TIMESTAMP)                            AS created_at,
    CAST(updated_at AS TIMESTAMP)                            AS updated_at,
    CAST(initially_assigned_at AS TIMESTAMP)                 AS initially_assigned_at,
    CAST(assigned_at AS TIMESTAMP)                           AS assigned_at,
    CAST(solved_at AS TIMESTAMP)                             AS solved_at,
    CAST(status_updated_at AS TIMESTAMP)                     AS status_updated_at,
    CAST(latest_comment_added_at AS TIMESTAMP)               AS latest_comment_added_at,
    CAST(reply_time_in_minutes_calendar AS INT64)            AS first_reply_minutes_calendar,
    CAST(reply_time_in_minutes_business AS INT64)            AS first_reply_minutes_business,
    CAST(first_resolution_time_in_minutes_calendar AS INT64) AS first_resolution_minutes_calendar,
    CAST(first_resolution_time_in_minutes_business AS INT64) AS first_resolution_minutes_business,
    CAST(full_resolution_time_in_minutes_calendar AS INT64)  AS full_resolution_minutes_calendar,
    CAST(full_resolution_time_in_minutes_business AS INT64)  AS full_resolution_minutes_business,
    CAST(requester_wait_time_in_minutes_calendar AS INT64)   AS requester_wait_minutes_calendar,
    CAST(requester_wait_time_in_minutes_business AS INT64)   AS requester_wait_minutes_business,
    CAST(agent_wait_time_in_minutes_calendar AS INT64)       AS agent_wait_minutes_calendar,
    CAST(agent_wait_time_in_minutes_business AS INT64)       AS agent_wait_minutes_business,
    CAST(on_hold_time_in_minutes_calendar AS INT64)          AS on_hold_minutes_calendar,
    CAST(on_hold_time_in_minutes_business AS INT64)          AS on_hold_minutes_business,
    CAST(reopens AS INT64)                                   AS reopens,
    CAST(replies AS INT64)                                   AS replies,
    CAST(group_stations AS INT64)                            AS group_stations,
    CAST(assignee_stations AS INT64)                         AS assignee_stations
FROM {{raw.zendesk.ticket_metric}}
WHERE ticket_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY updated_at DESC) = 1
