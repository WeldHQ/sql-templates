-- core.sprout_social.case_resolution
-- One row per customer care case with its timings: how long it has been open, or
-- how long it took to close. The case-level detail behind Sprout's case reporting.
--
-- Grain: one row per case.
-- Depends on: staging.sprout_social.cases, .group, .message
--
-- hours_to_close uses the last close: a case that was reopened and closed again
-- counts the full span. Open cases have NULL hours_to_close and a running
-- hours_open. message_count only sees messages in the synced message table.

WITH case_messages AS (
    SELECT
        case_id,
        COUNT(*)              AS message_count,
        COUNTIF(NOT is_sent)  AS received_messages,
        COUNTIF(is_sent)      AS sent_messages
    FROM {{staging.sprout_social.message}}
    WHERE case_id IS NOT NULL
    GROUP BY 1
)

SELECT
    c.case_id,
    g.customer_id,
    c.group_id,
    g.group_name,
    c.queue_id,
    c.case_type,
    c.case_priority,
    c.case_status,
    c.case_status = 'CLOSED'                               AS is_closed,
    c.created_at,
    DATE(c.created_at)                                     AS created_date,
    c.last_closed_at,
    DATE(c.last_closed_at)                                 AS closed_date,
    c.updated_at,
    IF(c.case_status = 'CLOSED',
       TIMESTAMP_DIFF(c.last_closed_at, c.created_at, MINUTE) / 60,
       NULL)                                               AS hours_to_close,
    IF(c.case_status = 'CLOSED',
       NULL,
       TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), c.created_at, MINUTE) / 60) AS hours_open,
    ARRAY_LENGTH(JSON_EXTRACT_STRING_ARRAY(c.assigned_to_json)) AS assignee_count,
    c.assigned_to_json,
    COALESCE(m.message_count, 0)                           AS message_count,
    COALESCE(m.received_messages, 0)                       AS received_messages,
    COALESCE(m.sent_messages, 0)                           AS sent_messages
FROM {{staging.sprout_social.cases}} c
-- group is one row per group_id and case_messages one row per case, so neither
-- join can fan out.
LEFT JOIN {{staging.sprout_social.group}} g
    ON g.group_id = c.group_id
LEFT JOIN case_messages m
    ON m.case_id = c.case_id
