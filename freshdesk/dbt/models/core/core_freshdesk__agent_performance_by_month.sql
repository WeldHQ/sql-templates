-- core_freshdesk__agent_performance_by_month
-- Per agent per month: replies sent, tickets they gave the first response on and
-- how fast, tickets currently assigned to them, and the CSAT they received.
-- Grain: month x freshdesk_account x agent.
-- Depends on: core.freshdesk.ticket_lifecycle, staging.freshdesk.ticket_conversation,
--             staging.freshdesk.satisfaction_rating, staging.freshdesk.agent
--
-- Each column is dated on its own event and attributed to the agent who did it:
--   replies_sent          the reply's date, the agent who sent it
--   first_responses       the first reply's date, the agent who sent it
--   tickets_assigned      the ticket's creation date, its CURRENT assignee
--                         (the connector syncs no assignment history)
--   csat_*                the survey answer's date, the agent on the response
-- So never divide one column by another from a different line above and call it
-- a rate. Medians do not roll up across months.

WITH tz AS (
    SELECT DISTINCT freshdesk_account, reporting_timezone
    FROM {{ ref('stg_freshdesk__ticket') }}
),

replies AS (
    SELECT
        c.freshdesk_account,
        c.user_id                                       AS agent_id,
        DATE_TRUNC(DATE(c.created_at, tz.reporting_timezone), MONTH) AS month,
        COUNT(*)                                        AS replies_sent
    FROM {{ ref('stg_freshdesk__ticket_conversation') }} c
    JOIN tz ON tz.freshdesk_account = c.freshdesk_account
    JOIN {{ ref('stg_freshdesk__agent') }} a
      ON a.freshdesk_account = c.freshdesk_account
     AND a.agent_id          = c.user_id
    WHERE NOT COALESCE(c.is_incoming, FALSE)
      AND NOT COALESCE(c.is_private, FALSE)
      AND c.source_code IS DISTINCT FROM 2
      AND NOT c.is_auto_response
    GROUP BY 1, 2, 3
),

first_responses AS (
    SELECT
        freshdesk_account,
        first_response_agent_id                         AS agent_id,
        DATE_TRUNC(first_response_date, MONTH)          AS month,
        COUNT(*)                                        AS first_responses,
        AVG(first_response_minutes)                     AS first_response_minutes_avg,
        APPROX_QUANTILES(first_response_minutes, 2)[SAFE_OFFSET(1)] AS first_response_minutes_median
    FROM {{ ref('core_freshdesk__ticket_lifecycle') }}
    WHERE first_response_agent_id IS NOT NULL
      AND NOT is_outbound
    GROUP BY 1, 2, 3
),

assigned AS (
    SELECT
        freshdesk_account,
        assignee_id                                     AS agent_id,
        DATE_TRUNC(created_date, MONTH)                 AS month,
        COUNT(*)                                        AS tickets_assigned,
        COUNTIF(is_resolved)                            AS tickets_assigned_resolved_now
    FROM {{ ref('core_freshdesk__ticket_lifecycle') }}
    WHERE assignee_id IS NOT NULL
    GROUP BY 1, 2, 3
),

csat AS (
    SELECT
        r.freshdesk_account,
        r.agent_id,
        DATE_TRUNC(DATE(r.created_at, tz.reporting_timezone), MONTH) AS month,
        COUNTIF(r.rating_value IS NOT NULL)             AS csat_responses,
        COUNTIF(r.rating_value > 100)                   AS csat_positive,
        COUNTIF(r.rating_value < 100)                   AS csat_negative
    FROM {{ ref('stg_freshdesk__satisfaction_rating') }} r
    JOIN tz ON tz.freshdesk_account = r.freshdesk_account
    WHERE r.agent_id IS NOT NULL
    GROUP BY 1, 2, 3
),

keys AS (
    SELECT freshdesk_account, agent_id, month FROM replies
    UNION DISTINCT
    SELECT freshdesk_account, agent_id, month FROM first_responses
    UNION DISTINCT
    SELECT freshdesk_account, agent_id, month FROM assigned
    UNION DISTINCT
    SELECT freshdesk_account, agent_id, month FROM csat
)

SELECT
    k.month,
    k.freshdesk_account,
    k.agent_id,
    a.agent_name,
    a.agent_email,
    a.is_deactivated,
    COALESCE(r.replies_sent, 0)                  AS replies_sent,
    COALESCE(f.first_responses, 0)               AS first_responses,
    f.first_response_minutes_avg,
    f.first_response_minutes_median,
    COALESCE(s.tickets_assigned, 0)              AS tickets_assigned,
    COALESCE(s.tickets_assigned_resolved_now, 0) AS tickets_assigned_resolved_now,
    COALESCE(c.csat_responses, 0)                AS csat_responses,
    COALESCE(c.csat_positive, 0)                 AS csat_positive,
    COALESCE(c.csat_negative, 0)                 AS csat_negative,
    SAFE_DIVIDE(c.csat_positive, c.csat_responses) AS csat_score
FROM keys k
LEFT JOIN {{ ref('stg_freshdesk__agent') }} a
       ON a.freshdesk_account = k.freshdesk_account AND a.agent_id = k.agent_id
LEFT JOIN replies r
       ON r.freshdesk_account = k.freshdesk_account AND r.agent_id = k.agent_id AND r.month = k.month
LEFT JOIN first_responses f
       ON f.freshdesk_account = k.freshdesk_account AND f.agent_id = k.agent_id AND f.month = k.month
LEFT JOIN assigned s
       ON s.freshdesk_account = k.freshdesk_account AND s.agent_id = k.agent_id AND s.month = k.month
LEFT JOIN csat c
       ON c.freshdesk_account = k.freshdesk_account AND c.agent_id = k.agent_id AND c.month = k.month
WHERE k.month IS NOT NULL
