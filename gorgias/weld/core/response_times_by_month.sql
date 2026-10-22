-- core.gorgias.response_times_by_month
-- First response time, resolution time, messages per ticket, one-touch and
-- zero-touch rates and satisfaction for the tickets created in each month: the
-- "Support performance" overview.
-- Grain: created month x gorgias_account x team x channel.
-- Depends on: core.gorgias.ticket_lifecycle
--
-- DATED ON TICKET CREATION, which is how Gorgias' own first response time and
-- resolution time statistics are dated. So the latest months fill in as tickets
-- get answered and closed: tickets_closed and the resolution figures for the
-- current month will keep rising for weeks.
--
-- Outbound tickets (the helpdesk wrote first) are excluded from first response
-- figures only; they count everywhere else.
--
-- SATISFACTION: Gorgias scores 1 to 5. average_survey_score is the mean score;
-- satisfaction_rate is the share of answers scored 4 or 5; response_rate is
-- answered over sent. Recompute ratios from the counts after rolling up.
-- Medians do not roll up either: query ticket_lifecycle for another grain.

SELECT
    DATE_TRUNC(created_date, MONTH)                            AS month,
    gorgias_account,
    team_id,
    ANY_VALUE(team_name)                                       AS team_name,
    channel,

    COUNT(*)                                                   AS tickets_created,
    COUNTIF(is_closed)                                         AS tickets_closed,
    COUNTIF(NOT is_outbound)                                   AS inbound_tickets,
    COUNTIF(NOT is_outbound AND first_response_at IS NOT NULL) AS inbound_tickets_responded,

    SUM(IF(is_outbound, NULL, first_response_minutes))         AS first_response_minutes_sum,
    AVG(IF(is_outbound, NULL, first_response_minutes))         AS first_response_minutes_avg,
    APPROX_QUANTILES(IF(is_outbound, NULL, first_response_minutes), 2)[SAFE_OFFSET(1)]
                                                               AS first_response_minutes_median,

    SUM(resolution_minutes)                                    AS resolution_minutes_sum,
    AVG(resolution_minutes)                                    AS resolution_minutes_avg,
    APPROX_QUANTILES(resolution_minutes, 2)[SAFE_OFFSET(1)]    AS resolution_minutes_median,

    SUM(agent_messages)                                        AS agent_messages,
    SUM(customer_messages)                                     AS customer_messages,
    SAFE_DIVIDE(SUM(agent_messages + customer_messages), COUNT(*)) AS messages_per_ticket,
    COUNTIF(is_one_touch)                                      AS one_touch_tickets,
    SAFE_DIVIDE(COUNTIF(is_one_touch), COUNTIF(is_closed))     AS one_touch_rate,
    COUNTIF(is_zero_touch)                                     AS zero_touch_tickets,

    COUNTIF(survey_sent_at IS NOT NULL)                        AS surveys_sent,
    COUNTIF(survey_score IS NOT NULL)                          AS surveys_scored,
    SUM(survey_score)                                          AS survey_score_sum,
    AVG(survey_score)                                          AS average_survey_score,
    SAFE_DIVIDE(COUNTIF(survey_score >= 4), COUNTIF(survey_score IS NOT NULL)) AS satisfaction_rate,
    SAFE_DIVIDE(COUNTIF(survey_score IS NOT NULL), COUNTIF(survey_sent_at IS NOT NULL)) AS survey_response_rate
FROM {{core.gorgias.ticket_lifecycle}}
GROUP BY 1, 2, 3, 5
