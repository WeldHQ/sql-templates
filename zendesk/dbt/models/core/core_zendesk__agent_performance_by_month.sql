-- core_zendesk__agent_performance_by_month
-- Solved tickets, reply and resolution times and CSAT per agent per month: the
-- "Agent activity" style leaderboard.
-- Grain: month x zendesk_account x assignee.
-- Depends on: core.zendesk.ticket_lifecycle
--
-- ATTRIBUTION is to the CURRENT assignee of each solved ticket, which is the
-- agent who owned it at solve time in almost every case. The connector syncs no
-- assignment history, so a ticket handed over after it was solved moves with it.
-- The first reply may have come from someone else: Zendesk's metric does not
-- record who replied.
--
-- Same population and dating as response_times_by_month: tickets solved in the
-- month, by latest solve date. Medians do not roll up; see that model's header.

SELECT
    DATE_TRUNC(resolved_date, MONTH)                         AS month,
    zendesk_account,
    assignee_id,
    ANY_VALUE(assignee_name)                                 AS assignee_name,
    ANY_VALUE(assignee_email)                                AS assignee_email,

    COUNT(*)                                                 AS tickets_solved,
    COUNTIF(is_one_touch)                                    AS one_touch_tickets,
    COUNTIF(was_reopened)                                    AS reopened_tickets,
    SUM(replies)                                             AS public_agent_replies,

    AVG(first_reply_minutes_calendar)                        AS first_reply_minutes_calendar_avg,
    APPROX_QUANTILES(first_reply_minutes_calendar, 2)[SAFE_OFFSET(1)] AS first_reply_minutes_calendar_median,
    AVG(full_resolution_minutes_calendar)                    AS full_resolution_minutes_calendar_avg,
    APPROX_QUANTILES(full_resolution_minutes_calendar, 2)[SAFE_OFFSET(1)] AS full_resolution_minutes_calendar_median,
    AVG(full_resolution_minutes_business)                    AS full_resolution_minutes_business_avg,
    APPROX_QUANTILES(full_resolution_minutes_business, 2)[SAFE_OFFSET(1)] AS full_resolution_minutes_business_median,

    COUNTIF(is_csat_good)                                    AS csat_good,
    COUNTIF(is_csat_bad)                                     AS csat_bad,
    SAFE_DIVIDE(COUNTIF(is_csat_good), COUNTIF(has_csat_rating)) AS csat_score
FROM {{ ref('core_zendesk__ticket_lifecycle') }}
WHERE is_solved
  AND resolved_date IS NOT NULL
GROUP BY 1, 2, 3
