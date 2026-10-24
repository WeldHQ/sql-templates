-- core_zendesk__response_times_by_month
-- First reply time, full resolution time, requester wait time and CSAT for the
-- tickets solved in each month: the "Efficiency" and "Satisfaction" views of
-- Zendesk's Support dashboard.
-- Grain: month x zendesk_account x group x channel.
-- Depends on: core.zendesk.ticket_lifecycle
--
-- POPULATION: tickets solved (or closed) in the month, by their latest solve
-- date. That matches how Explore's efficiency metrics are usually dated, and it
-- means every ticket in a row has a finished resolution time. Unsolved tickets
-- are in ticket_volume_by_day, not here.
--
-- MEDIANS do not add up. A month's median across all groups is not the average
-- of the group medians, so never roll this table up in BI for a median. Sum the
-- _sum_ and ticket columns and divide for a mean at any level; for a median at a
-- coarser grain, query ticket_lifecycle directly. Medians use APPROX_QUANTILES,
-- which is approximate on large inputs.
--
-- CSAT is dated on the solve month as well: the rating on the ticket carries no
-- timestamp of its own. csat_score = good / (good + bad), Zendesk's formula.

WITH solved AS (
    SELECT *
    FROM {{ ref('core_zendesk__ticket_lifecycle') }}
    WHERE is_solved
      AND resolved_date IS NOT NULL
)

SELECT
    DATE_TRUNC(resolved_date, MONTH)                         AS month,
    zendesk_account,
    group_id,
    ANY_VALUE(group_name)                                    AS group_name,
    channel,

    COUNT(*)                                                 AS tickets_solved,
    COUNTIF(first_reply_minutes_calendar IS NOT NULL)        AS tickets_with_first_reply,
    COUNTIF(is_one_touch)                                    AS one_touch_tickets,
    SAFE_DIVIDE(COUNTIF(is_one_touch), COUNT(*))             AS one_touch_rate,
    COUNTIF(is_two_touch)                                    AS two_touch_tickets,
    COUNTIF(is_multi_touch)                                  AS multi_touch_tickets,
    COUNTIF(was_reopened)                                    AS reopened_tickets,
    SUM(reopens)                                             AS reopens,

    -- First reply time, minutes.
    SUM(first_reply_minutes_calendar)                        AS first_reply_minutes_calendar_sum,
    AVG(first_reply_minutes_calendar)                        AS first_reply_minutes_calendar_avg,
    APPROX_QUANTILES(first_reply_minutes_calendar, 2)[SAFE_OFFSET(1)] AS first_reply_minutes_calendar_median,
    AVG(first_reply_minutes_business)                        AS first_reply_minutes_business_avg,
    APPROX_QUANTILES(first_reply_minutes_business, 2)[SAFE_OFFSET(1)] AS first_reply_minutes_business_median,

    -- Full resolution time (creation to latest solve), minutes.
    SUM(full_resolution_minutes_calendar)                    AS full_resolution_minutes_calendar_sum,
    AVG(full_resolution_minutes_calendar)                    AS full_resolution_minutes_calendar_avg,
    APPROX_QUANTILES(full_resolution_minutes_calendar, 2)[SAFE_OFFSET(1)] AS full_resolution_minutes_calendar_median,
    AVG(full_resolution_minutes_business)                    AS full_resolution_minutes_business_avg,
    APPROX_QUANTILES(full_resolution_minutes_business, 2)[SAFE_OFFSET(1)] AS full_resolution_minutes_business_median,

    -- Requester wait time: time the ticket spent in new, open or on hold.
    AVG(requester_wait_minutes_calendar)                     AS requester_wait_minutes_calendar_avg,
    APPROX_QUANTILES(requester_wait_minutes_calendar, 2)[SAFE_OFFSET(1)] AS requester_wait_minutes_calendar_median,
    AVG(requester_wait_minutes_business)                     AS requester_wait_minutes_business_avg,
    APPROX_QUANTILES(requester_wait_minutes_business, 2)[SAFE_OFFSET(1)] AS requester_wait_minutes_business_median,

    -- CSAT.
    COUNTIF(was_csat_offered)                                AS csat_offered,
    COUNTIF(is_csat_good)                                    AS csat_good,
    COUNTIF(is_csat_bad)                                     AS csat_bad,
    SAFE_DIVIDE(COUNTIF(is_csat_good), COUNTIF(has_csat_rating)) AS csat_score,
    SAFE_DIVIDE(COUNTIF(has_csat_rating), COUNTIF(was_csat_offered)) AS csat_response_rate
FROM solved
GROUP BY 1, 2, 3, 5
