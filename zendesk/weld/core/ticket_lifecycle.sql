-- core.zendesk.ticket_lifecycle
-- One row per ticket with its dimensions, Zendesk's own time metrics and CSAT.
-- Grain: zendesk_account x ticket. The other three core models read this one.
--
-- WHAT COUNTS AS SOLVED: status `solved` or `closed`. `new`, `open`, `pending`
-- and `hold` are unsolved, which is Zendesk's own "unsolved tickets" definition.
-- Deleted tickets are dropped here: Zendesk Explore leaves them out too, and the
-- incremental export keeps returning them with status `deleted`.
--
-- resolved_at: ticket_metric.solved_at, the LATEST solve. A ticket merged into
-- another is closed without ever being solved, so solved_at is empty; for those
-- the time the status last changed is used instead, otherwise a merged ticket
-- would sit in the backlog forever. A ticket that is unsolved right now has no
-- resolved_at even if it was solved once before and then reopened.
--
-- Time metrics are copied from ticket_metric in minutes, calendar and business.
-- Calendar is wall clock time, business follows the schedule on the ticket.
-- Report the one your team is measured on; mixing them is the usual reason a
-- warehouse number disagrees with Explore.

WITH tickets AS (
    SELECT *
    FROM {{staging.zendesk.ticket}}
    WHERE status IS DISTINCT FROM 'deleted'
)

SELECT
    t.zendesk_account,
    t.ticket_id,
    t.subject,
    t.status,
    t.status IN ('solved', 'closed')                       AS is_solved,
    t.status IN ('new', 'open', 'pending', 'hold')         AS is_unsolved,
    t.priority,
    t.ticket_type,
    COALESCE(t.channel, 'unknown')                         AS channel,
    t.group_id,
    COALESCE(g.group_name, IF(t.group_id IS NULL, 'No group', NULL)) AS group_name,
    t.assignee_id,
    COALESCE(a.user_name, IF(t.assignee_id IS NULL, 'Unassigned', NULL)) AS assignee_name,
    a.email                                                AS assignee_email,
    t.requester_id,
    t.organization_id,
    t.brand_id,

    t.reporting_timezone,
    t.created_at,
    DATE(t.created_at, t.reporting_timezone)               AS created_date,
    CASE WHEN t.status IN ('solved', 'closed')
         THEN COALESCE(m.solved_at, m.status_updated_at, t.updated_at) END AS resolved_at,
    DATE(CASE WHEN t.status IN ('solved', 'closed')
              THEN COALESCE(m.solved_at, m.status_updated_at, t.updated_at) END,
         t.reporting_timezone)                             AS resolved_date,
    m.initially_assigned_at,

    m.first_reply_minutes_calendar,
    m.first_reply_minutes_business,
    m.first_resolution_minutes_calendar,
    m.first_resolution_minutes_business,
    m.full_resolution_minutes_calendar,
    m.full_resolution_minutes_business,
    m.requester_wait_minutes_calendar,
    m.requester_wait_minutes_business,
    m.agent_wait_minutes_calendar,
    m.on_hold_minutes_calendar,
    m.replies,
    m.reopens,
    m.group_stations,
    m.assignee_stations,
    -- Zendesk's "one-touch": solved with exactly one public agent reply.
    t.status IN ('solved', 'closed') AND m.replies = 1     AS is_one_touch,
    COALESCE(m.reopens, 0) > 0                             AS was_reopened,

    -- CSAT. `offered` means a survey went out and nobody answered; `unoffered`
    -- means no survey was sent. Only good and bad are ratings.
    t.satisfaction_score,
    t.satisfaction_reason,
    t.satisfaction_score IN ('good', 'bad')                AS has_csat_rating,
    t.satisfaction_score = 'good'                          AS is_csat_good,
    t.satisfaction_score = 'bad'                           AS is_csat_bad,
    t.satisfaction_score IN ('offered', 'good', 'bad')     AS was_csat_offered
FROM tickets t
LEFT JOIN {{staging.zendesk.ticket_metric}} m
       ON m.zendesk_account = t.zendesk_account
      AND m.ticket_id       = t.ticket_id
LEFT JOIN {{staging.zendesk.group}} g
       ON g.zendesk_account = t.zendesk_account
      AND g.group_id        = t.group_id
LEFT JOIN {{staging.zendesk.user}} a
       ON a.zendesk_account = t.zendesk_account
      AND a.user_id         = t.assignee_id
