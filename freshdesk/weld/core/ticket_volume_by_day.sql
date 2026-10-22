-- core.freshdesk.ticket_volume_by_day
-- Tickets created, tickets first responded to, and reply traffic per day.
-- Grain: day x freshdesk_account x group x channel.
-- Depends on: core.freshdesk.ticket_lifecycle, staging.freshdesk.ticket_conversation
--
-- Built on a day spine, so a quiet group or channel returns zeros instead of a gap.
--
-- NO RESOLVED COUNT AND NO BACKLOG HISTORY. The connector does not sync when a
-- ticket was resolved, so "resolved per day" and the backlog on a past day cannot
-- be computed. unresolved_now is a snapshot of tickets created on that day that
-- are still unresolved today, not a backlog. Materialise ticket_lifecycle daily
-- and keep the runs if you need a backlog trend.
--
-- Each metric is dated on its own event: created on creation, first responses on
-- the reply, replies on the reply. Groups and channels are the ticket's current ones.

WITH tickets AS (
    SELECT *, IFNULL(group_id, '') AS group_key
    FROM {{core.freshdesk.ticket_lifecycle}}
    WHERE created_date IS NOT NULL
),

replies AS (
    SELECT
        t.freshdesk_account,
        t.group_key,
        t.channel,
        DATE(c.created_at, t.reporting_timezone) AS day,
        COUNTIF(c.is_incoming)                                            AS customer_replies,
        COUNTIF(NOT COALESCE(c.is_incoming, FALSE)
                AND NOT COALESCE(c.is_private, FALSE)
                AND c.source_code IS DISTINCT FROM 2
                AND NOT c.is_auto_response)                               AS public_outgoing_replies
    FROM {{staging.freshdesk.ticket_conversation}} c
    JOIN tickets t
      ON t.freshdesk_account = c.freshdesk_account
     AND t.ticket_id         = c.ticket_id
    GROUP BY 1, 2, 3, 4
),

events AS (
    SELECT freshdesk_account, group_key, channel, created_date AS day,
           1 AS created, IF(is_resolved, 0, 1) AS unresolved, 0 AS first_responded
    FROM tickets
    UNION ALL
    SELECT freshdesk_account, group_key, channel, first_response_date AS day,
           0, 0, 1
    FROM tickets
    WHERE first_response_date IS NOT NULL
),

daily AS (
    SELECT freshdesk_account, group_key, channel, day,
           SUM(created)         AS tickets_created,
           SUM(unresolved)      AS unresolved_now,
           SUM(first_responded) AS tickets_first_responded
    FROM events
    GROUP BY 1, 2, 3, 4
),

dims AS (
    SELECT
        freshdesk_account,
        group_key,
        channel,
        ANY_VALUE(group_id)   AS group_id,
        ANY_VALUE(group_name) AS group_name,
        MIN(created_date)     AS first_day
    FROM tickets
    GROUP BY 1, 2, 3
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(created_date) FROM tickets),
        GREATEST(CURRENT_DATE(), (SELECT MAX(day) FROM daily))
    )) AS day
)

SELECT
    s.day,
    d.freshdesk_account,
    d.group_id,
    d.group_name,
    d.channel,
    COALESCE(x.tickets_created, 0)          AS tickets_created,
    COALESCE(x.tickets_first_responded, 0)  AS tickets_first_responded,
    COALESCE(r.public_outgoing_replies, 0)  AS public_outgoing_replies,
    COALESCE(r.customer_replies, 0)         AS customer_replies,
    COALESCE(x.unresolved_now, 0)           AS unresolved_now
FROM day_spine s
CROSS JOIN dims d
LEFT JOIN daily x
       ON x.freshdesk_account = d.freshdesk_account
      AND x.group_key         = d.group_key
      AND x.channel           = d.channel
      AND x.day               = s.day
LEFT JOIN replies r
       ON r.freshdesk_account = d.freshdesk_account
      AND r.group_key         = d.group_key
      AND r.channel           = d.channel
      AND r.day               = s.day
WHERE s.day >= d.first_day
