-- core.freshdesk.first_response_by_month
-- First response time (mean and median, calendar minutes) and first-response SLA
-- attainment for the tickets created in each month: the "First response time"
-- and "SLA" panels of Freshdesk's Helpdesk In-depth report.
-- Grain: created month x freshdesk_account x group x channel.
-- Depends on: core.freshdesk.ticket_lifecycle
--
-- POPULATION: inbound tickets created in the month. Outbound email tickets are
-- left out, because an agent wrote them and there is nothing to respond to.
-- Tickets created this month that have not been answered yet count in
-- tickets_created and not in tickets_responded, so the current month's
-- response rate rises as replies come in.
--
-- MEDIANS do not add up across groups or channels. Sum the _sum_ and count
-- columns for a mean at any level; query ticket_lifecycle for a median at a
-- coarser grain. Medians use APPROX_QUANTILES.

SELECT
    DATE_TRUNC(created_date, MONTH)                           AS month,
    freshdesk_account,
    group_id,
    ANY_VALUE(group_name)                                     AS group_name,
    channel,

    COUNT(*)                                                  AS tickets_created,
    COUNTIF(first_response_at IS NOT NULL)                    AS tickets_responded,
    COUNTIF(is_resolved)                                      AS resolved_now,
    COUNTIF(NOT is_resolved)                                  AS unresolved_now,

    SUM(first_response_minutes)                               AS first_response_minutes_sum,
    AVG(first_response_minutes)                               AS first_response_minutes_avg,
    APPROX_QUANTILES(first_response_minutes, 2)[SAFE_OFFSET(1)] AS first_response_minutes_median,
    APPROX_QUANTILES(first_response_minutes, 10)[SAFE_OFFSET(9)] AS first_response_minutes_p90,

    COUNTIF(is_first_response_within_sla)                     AS first_response_within_sla,
    COUNTIF(is_first_response_within_sla IS NOT NULL)         AS first_response_sla_measured,
    SAFE_DIVIDE(COUNTIF(is_first_response_within_sla),
                COUNTIF(is_first_response_within_sla IS NOT NULL)) AS first_response_sla_rate,

    SUM(agent_replies)                                        AS agent_replies,
    SAFE_DIVIDE(SUM(agent_replies), COUNTIF(first_response_at IS NOT NULL)) AS agent_replies_per_responded_ticket
FROM {{core.freshdesk.ticket_lifecycle}}
WHERE NOT is_outbound
  AND created_date IS NOT NULL
GROUP BY 1, 2, 3, 5
