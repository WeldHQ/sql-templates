-- core.gorgias.ticket_lifecycle
-- One row per ticket with its dimensions, first response and resolution times
-- derived from the message log and close timestamp, message counts and CSAT.
-- Grain: gorgias_account x ticket. The other ticket models read this one.
--
-- EXCLUDED: spam, trashed and merged tickets. Gorgias' statistics leave them out,
-- and a merged ticket's messages live on in the ticket it was merged into.
--
-- FIRST RESPONSE is the first public message from the helpdesk side that was not
-- sent by a rule, after the customer's first message:
--   start  = the customer's first message (the ticket's creation time if none)
--   reply  = earliest message with from_agent, public, rule_id empty, after start
-- Messages written by AI Agent or by an app through the API are counted as agent
-- replies, because nothing on the synced message reliably marks them.
-- first_response_via shows how the reply was sent, so you can filter.
-- Tickets the helpdesk started (outbound) are flagged and left out of averages.
--
-- RESOLUTION is creation to the ticket's LATEST close. Gorgias overwrites
-- closed_datetime when a reopened ticket is closed again, so a ticket closed,
-- reopened and closed counts once, on its last close. resolved_at is NULL for a
-- ticket that is open now.
--
-- All durations are calendar minutes. Gorgias does not apply business hours.

WITH tickets AS (
    SELECT *
    FROM {{staging.gorgias.ticket}}
    WHERE NOT is_spam
      AND NOT is_merged
      AND trashed_at IS NULL
      AND created_at IS NOT NULL
),

messages AS (
    SELECT *
    FROM {{staging.gorgias.ticket_message}}
    WHERE failed_at IS NULL
),

first_customer AS (
    SELECT gorgias_account, ticket_id, MIN(created_at) AS first_customer_message_at
    FROM messages
    WHERE NOT is_from_agent
    GROUP BY 1, 2
),

agent_replies AS (
    SELECT
        m.gorgias_account,
        m.ticket_id,
        m.created_at,
        m.sender_id,
        m.sender_name,
        m.via
    FROM messages m
    WHERE m.is_from_agent
      AND m.is_public
      AND m.rule_id IS NULL
),

first_reply AS (
    SELECT
        r.gorgias_account,
        r.ticket_id,
        ARRAY_AGG(STRUCT(r.created_at, r.sender_id, r.sender_name, r.via)
                  ORDER BY r.created_at LIMIT 1)[OFFSET(0)] AS reply
    FROM agent_replies r
    JOIN tickets t
      ON t.gorgias_account = r.gorgias_account
     AND t.ticket_id       = r.ticket_id
    LEFT JOIN first_customer fc
      ON fc.gorgias_account = r.gorgias_account
     AND fc.ticket_id       = r.ticket_id
    WHERE r.created_at >= COALESCE(fc.first_customer_message_at, t.created_at)
    GROUP BY 1, 2
),

message_counts AS (
    SELECT
        gorgias_account,
        ticket_id,
        COUNTIF(is_from_agent AND is_public AND rule_id IS NULL) AS agent_messages,
        COUNTIF(is_from_agent AND rule_id IS NOT NULL)           AS rule_messages,
        COUNTIF(NOT is_from_agent)                               AS customer_messages,
        COUNTIF(NOT is_public)                                   AS internal_notes
    FROM messages
    GROUP BY 1, 2
),

surveys AS (
    SELECT *
    FROM {{staging.gorgias.satisfaction_survey}}
    WHERE ticket_id IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY gorgias_account, ticket_id ORDER BY created_at DESC) = 1
)

SELECT
    t.gorgias_account,
    t.ticket_id,
    t.subject,
    t.status,
    t.status = 'closed'                                      AS is_closed,
    t.snoozed_until IS NOT NULL AND t.status = 'open'        AS is_snoozed,
    t.priority,
    COALESCE(t.channel, 'unknown')                           AS channel,
    t.via,
    t.language,
    COALESCE(t.is_from_agent, FALSE)                         AS is_outbound,
    t.team_id,
    COALESCE(t.team_name, IF(t.team_id IS NULL, 'No team', NULL)) AS team_name,
    t.assignee_id,
    COALESCE(t.assignee_name, IF(t.assignee_id IS NULL, 'Unassigned', NULL)) AS assignee_name,
    t.assignee_email,
    t.customer_id,

    t.reporting_timezone,
    t.created_at,
    DATE(t.created_at, t.reporting_timezone)                 AS created_date,
    -- updated_at only stands in for a closed ticket missing its close time, so a
    -- closed ticket can never sit in the open backlog.
    CASE WHEN t.status = 'closed' THEN COALESCE(t.closed_at, t.updated_at) END AS resolved_at,
    DATE(CASE WHEN t.status = 'closed' THEN COALESCE(t.closed_at, t.updated_at) END,
         t.reporting_timezone)                               AS resolved_date,

    fc.first_customer_message_at,
    fr.reply.created_at                                      AS first_response_at,
    fr.reply.sender_id                                       AS first_response_agent_id,
    fr.reply.sender_name                                     AS first_response_agent_name,
    fr.reply.via                                             AS first_response_via,
    TIMESTAMP_DIFF(fr.reply.created_at,
                   COALESCE(fc.first_customer_message_at, t.created_at), SECOND) / 60.0
                                                             AS first_response_minutes,
    CASE WHEN t.status = 'closed'
         THEN TIMESTAMP_DIFF(t.closed_at, t.created_at, SECOND) / 60.0 END
                                                             AS resolution_minutes,

    COALESCE(mc.agent_messages, 0)                           AS agent_messages,
    COALESCE(mc.rule_messages, 0)                            AS rule_messages,
    COALESCE(mc.customer_messages, 0)                        AS customer_messages,
    COALESCE(mc.internal_notes, 0)                           AS internal_notes,
    -- Gorgias' "one-touch": closed after a single agent message.
    t.status = 'closed' AND COALESCE(mc.agent_messages, 0) = 1 AS is_one_touch,
    -- "Zero-touch": closed with no agent message (rules, automation, or closed unanswered).
    t.status = 'closed' AND COALESCE(mc.agent_messages, 0) = 0 AS is_zero_touch,

    s.sent_at                                                AS survey_sent_at,
    s.scored_at                                              AS survey_scored_at,
    s.score                                                  AS survey_score
FROM tickets t
LEFT JOIN first_customer fc
       ON fc.gorgias_account = t.gorgias_account
      AND fc.ticket_id       = t.ticket_id
LEFT JOIN first_reply fr
       ON fr.gorgias_account = t.gorgias_account
      AND fr.ticket_id       = t.ticket_id
LEFT JOIN message_counts mc
       ON mc.gorgias_account = t.gorgias_account
      AND mc.ticket_id       = t.ticket_id
LEFT JOIN surveys s
       ON s.gorgias_account = t.gorgias_account
      AND s.ticket_id       = t.ticket_id
