-- core_gorgias__agent_performance_by_month
-- Per agent per month: tickets closed and how fast, messages sent, first
-- responses given, and satisfaction on their tickets.
-- Grain: month x gorgias_account x agent.
-- Depends on: core.gorgias.ticket_lifecycle, staging.gorgias.ticket_message
--
-- Each block is dated and attributed on its own event:
--   tickets_closed, resolution_*, survey_*   closed month, the CURRENT assignee
--   first_responses, first_response_*        first reply month, the agent who sent it
--   messages_sent                            message month, the sender
-- The connector syncs no assignment history, so closed tickets go to whoever is
-- assigned now. Do not divide a column by one from another block.
-- Medians do not roll up across months.

WITH tz AS (
    SELECT DISTINCT gorgias_account, reporting_timezone
    FROM {{ ref('core_gorgias__ticket_lifecycle') }}
),

closed AS (
    SELECT
        gorgias_account,
        assignee_id                                        AS agent_id,
        DATE_TRUNC(resolved_date, MONTH)                   AS month,
        ANY_VALUE(assignee_name)                           AS agent_name,
        COUNT(*)                                           AS tickets_closed,
        COUNTIF(is_one_touch)                              AS one_touch_tickets,
        AVG(resolution_minutes)                            AS resolution_minutes_avg,
        APPROX_QUANTILES(resolution_minutes, 2)[SAFE_OFFSET(1)] AS resolution_minutes_median,
        COUNTIF(survey_score IS NOT NULL)                  AS surveys_scored,
        AVG(survey_score)                                  AS average_survey_score,
        SAFE_DIVIDE(COUNTIF(survey_score >= 4), COUNTIF(survey_score IS NOT NULL)) AS satisfaction_rate
    FROM {{ ref('core_gorgias__ticket_lifecycle') }}
    WHERE is_closed AND assignee_id IS NOT NULL AND resolved_date IS NOT NULL
    GROUP BY 1, 2, 3
),

first_responses AS (
    SELECT
        l.gorgias_account,
        l.first_response_agent_id                          AS agent_id,
        DATE_TRUNC(DATE(l.first_response_at, l.reporting_timezone), MONTH) AS month,
        ANY_VALUE(l.first_response_agent_name)             AS agent_name,
        COUNT(*)                                           AS first_responses,
        AVG(l.first_response_minutes)                      AS first_response_minutes_avg,
        APPROX_QUANTILES(l.first_response_minutes, 2)[SAFE_OFFSET(1)] AS first_response_minutes_median
    FROM {{ ref('core_gorgias__ticket_lifecycle') }} l
    WHERE l.first_response_agent_id IS NOT NULL AND NOT l.is_outbound
    GROUP BY 1, 2, 3
),

messages AS (
    SELECT
        m.gorgias_account,
        m.sender_id                                        AS agent_id,
        DATE_TRUNC(DATE(m.created_at, tz.reporting_timezone), MONTH) AS month,
        ANY_VALUE(m.sender_name)                           AS agent_name,
        COUNT(*)                                           AS messages_sent
    FROM {{ ref('stg_gorgias__ticket_message') }} m
    JOIN tz ON tz.gorgias_account = m.gorgias_account
    WHERE m.is_from_agent AND m.is_public AND m.rule_id IS NULL
      AND m.failed_at IS NULL AND m.sender_id IS NOT NULL
    GROUP BY 1, 2, 3
),

keys AS (
    SELECT gorgias_account, agent_id, month FROM closed
    UNION DISTINCT
    SELECT gorgias_account, agent_id, month FROM first_responses
    UNION DISTINCT
    SELECT gorgias_account, agent_id, month FROM messages
)

SELECT
    k.month,
    k.gorgias_account,
    k.agent_id,
    COALESCE(c.agent_name, f.agent_name, m.agent_name) AS agent_name,
    COALESCE(c.tickets_closed, 0)                      AS tickets_closed,
    COALESCE(c.one_touch_tickets, 0)                   AS one_touch_tickets,
    c.resolution_minutes_avg,
    c.resolution_minutes_median,
    COALESCE(f.first_responses, 0)                     AS first_responses,
    f.first_response_minutes_avg,
    f.first_response_minutes_median,
    COALESCE(m.messages_sent, 0)                       AS messages_sent,
    COALESCE(c.surveys_scored, 0)                      AS surveys_scored,
    c.average_survey_score,
    c.satisfaction_rate
FROM keys k
LEFT JOIN closed c
       ON c.gorgias_account = k.gorgias_account AND c.agent_id = k.agent_id AND c.month = k.month
LEFT JOIN first_responses f
       ON f.gorgias_account = k.gorgias_account AND f.agent_id = k.agent_id AND f.month = k.month
LEFT JOIN messages m
       ON m.gorgias_account = k.gorgias_account AND m.agent_id = k.agent_id AND m.month = k.month
WHERE k.month IS NOT NULL
