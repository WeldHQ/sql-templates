-- core_freshdesk__ticket_lifecycle
-- One row per ticket with its dimensions, a first response time derived from the
-- conversation log, reply counts and the latest CSAT answer.
-- Grain: freshdesk_account x ticket. The other core models read this one.
--
-- FIRST RESPONSE is the earliest conversation that is
--   * sent by an agent (user_id is in `agent`),
--   * not incoming, not private, not a note (source_code 2), and
--   * not an automated reply.
-- first_response_minutes is calendar time from ticket creation to that reply.
-- Freshdesk's own report can also show business hours; ticket stats are not
-- synced, so only calendar time is available. Outbound tickets
-- (an agent wrote first) are flagged and left out of response-time averages.
--
-- RESOLUTION TIME IS NOT HERE. There is no resolved_at or closed_at,
-- and updated_at moves on every later edit (Freshdesk's auto-close alone adds
-- days), so any resolution time built from it would be wrong. is_resolved says
-- whether a ticket is resolved NOW, which is all the data supports.
--
-- Spam is dropped. Freshdesk's ticket list hides spam and deleted tickets, so a
-- ticket marked spam or deleted after it was synced stops updating and stays in
-- the warehouse with its last state; see the README.

WITH tickets AS (
    SELECT *
    FROM {{ ref('stg_freshdesk__ticket') }}
    WHERE NOT is_spam
),

agent_replies AS (
    SELECT
        c.freshdesk_account,
        c.ticket_id,
        c.user_id,
        c.created_at
    FROM {{ ref('stg_freshdesk__ticket_conversation') }} c
    JOIN {{ ref('stg_freshdesk__agent') }} a
      ON a.freshdesk_account = c.freshdesk_account
     AND a.agent_id          = c.user_id
    WHERE NOT COALESCE(c.is_incoming, FALSE)
      AND NOT COALESCE(c.is_private, FALSE)
      AND c.source_code IS DISTINCT FROM 2
      AND NOT c.is_auto_response
),

reply_stats AS (
    SELECT
        freshdesk_account,
        ticket_id,
        COUNT(*)                                             AS agent_replies,
        MIN(created_at)                                      AS first_response_at,
        ARRAY_AGG(user_id ORDER BY created_at LIMIT 1)[OFFSET(0)] AS first_response_agent_id
    FROM agent_replies
    GROUP BY 1, 2
),

customer_messages AS (
    SELECT freshdesk_account, ticket_id, COUNT(*) AS customer_replies
    FROM {{ ref('stg_freshdesk__ticket_conversation') }}
    WHERE is_incoming
    GROUP BY 1, 2
),

latest_rating AS (
    SELECT freshdesk_account, ticket_id, rating_value, created_at AS rated_at
    FROM {{ ref('stg_freshdesk__satisfaction_rating') }}
    WHERE ticket_id IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY freshdesk_account, ticket_id ORDER BY created_at DESC) = 1
)

SELECT
    t.freshdesk_account,
    t.ticket_id,
    t.subject,
    t.status_code,
    t.status,
    COALESCE(t.status_code IN (4, 5), FALSE)                 AS is_resolved,
    t.priority,
    t.ticket_type,
    t.channel,
    COALESCE(t.source_code = 10, FALSE)                      AS is_outbound,
    t.group_id,
    COALESCE(g.group_name, IF(t.group_id IS NULL, 'No group', NULL)) AS group_name,
    t.responder_id                                           AS assignee_id,
    COALESCE(a.agent_name, IF(t.responder_id IS NULL, 'Unassigned', NULL)) AS assignee_name,
    t.requester_id,
    t.company_id,
    t.product_id,

    t.reporting_timezone,
    t.created_at,
    DATE(t.created_at, t.reporting_timezone)                 AS created_date,

    r.first_response_at,
    DATE(r.first_response_at, t.reporting_timezone)          AS first_response_date,
    r.first_response_agent_id,
    fa.agent_name                                            AS first_response_agent_name,
    TIMESTAMP_DIFF(r.first_response_at, t.created_at, SECOND) / 60.0 AS first_response_minutes,
    t.first_response_due_at,
    -- Met the first-response SLA target Freshdesk set on the ticket. NULL when
    -- the ticket has no reply yet or no target.
    CASE WHEN r.first_response_at IS NOT NULL AND t.first_response_due_at IS NOT NULL
         THEN r.first_response_at <= t.first_response_due_at END AS is_first_response_within_sla,
    t.is_first_response_escalated,
    t.resolution_due_at,
    t.is_resolution_escalated,

    COALESCE(r.agent_replies, 0)                             AS agent_replies,
    COALESCE(cm.customer_replies, 0)                         AS customer_replies,

    lr.rating_value                                          AS csat_rating_value,
    lr.rated_at                                              AS csat_rated_at,
    lr.rating_value > 100                                    AS is_csat_positive,
    lr.rating_value = 100                                    AS is_csat_neutral,
    lr.rating_value < 100                                    AS is_csat_negative
FROM tickets t
LEFT JOIN reply_stats r
       ON r.freshdesk_account = t.freshdesk_account
      AND r.ticket_id         = t.ticket_id
LEFT JOIN customer_messages cm
       ON cm.freshdesk_account = t.freshdesk_account
      AND cm.ticket_id         = t.ticket_id
LEFT JOIN latest_rating lr
       ON lr.freshdesk_account = t.freshdesk_account
      AND lr.ticket_id         = t.ticket_id
LEFT JOIN {{ ref('stg_freshdesk__group') }} g
       ON g.freshdesk_account = t.freshdesk_account
      AND g.group_id          = t.group_id
LEFT JOIN {{ ref('stg_freshdesk__agent') }} a
       ON a.freshdesk_account = t.freshdesk_account
      AND a.agent_id          = t.responder_id
LEFT JOIN {{ ref('stg_freshdesk__agent') }} fa
       ON fa.freshdesk_account = t.freshdesk_account
      AND fa.agent_id          = r.first_response_agent_id
