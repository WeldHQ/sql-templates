-- core.freshdesk.csat_by_month
-- Customer satisfaction per month, by the group and agent the response was given
-- for: Freshdesk's "Satisfaction survey" report.
-- Grain: response month x freshdesk_account x group x agent.
-- Depends on: staging.freshdesk.satisfaction_rating, agent, group
--
-- Dated on when the customer answered, which is how Freshdesk's report dates it.
-- Agent and group come from the response itself, not from the ticket's current
-- state, so a ticket reassigned after the survey keeps its rating where it was.
--
-- csat_score = positive / all answers to the default question. Freshdesk counts
-- neutral answers in the denominator, so they are kept there. Every count column
-- is additive; csat_score is not, so recompute it from the counts after rolling up.

WITH ratings AS (
    SELECT
        r.*,
        DATE(r.created_at, t.reporting_timezone) AS rated_date
    FROM {{staging.freshdesk.satisfaction_rating}} r
    -- Only for the time zone; one row per helpdesk is enough.
    JOIN (SELECT DISTINCT freshdesk_account, reporting_timezone
          FROM {{staging.freshdesk.ticket}}) t
      ON t.freshdesk_account = r.freshdesk_account
)

SELECT
    DATE_TRUNC(r.rated_date, MONTH)                  AS month,
    r.freshdesk_account,
    r.group_id,
    ANY_VALUE(g.group_name)                          AS group_name,
    r.agent_id,
    ANY_VALUE(a.agent_name)                          AS agent_name,

    COUNT(*)                                         AS survey_responses,
    COUNTIF(r.rating_value IS NOT NULL)              AS rated_responses,
    COUNTIF(r.rating_value > 100)                    AS positive,
    COUNTIF(r.rating_value = 100)                    AS neutral,
    COUNTIF(r.rating_value < 100)                    AS negative,
    SAFE_DIVIDE(COUNTIF(r.rating_value > 100),
                COUNTIF(r.rating_value IS NOT NULL)) AS csat_score
FROM ratings r
LEFT JOIN {{staging.freshdesk.group}} g
       ON g.freshdesk_account = r.freshdesk_account
      AND g.group_id          = r.group_id
LEFT JOIN {{staging.freshdesk.agent}} a
       ON a.freshdesk_account = r.freshdesk_account
      AND a.agent_id          = r.agent_id
WHERE r.rated_date IS NOT NULL
GROUP BY 1, 2, 3, 5
