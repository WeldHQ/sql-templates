-- core_gorgias__voice_calls_by_day
-- Phone calls handled by Gorgias Voice per day: volume, answered, voicemail and
-- talk time, the core of the "Voice" statistics.
-- Grain: day x gorgias_account x direction x status.
-- Depends on: staging.gorgias.voice_call
--
-- Dated on when the call started (created time if the provider sent no start).
--
-- ANSWERED means Gorgias recorded an agent, or an external forwarding number, as
-- having answered. Gorgias does not publish the full list of status and
-- termination_status values, so the status is kept as a dimension instead of
-- being mapped to missed/abandoned buckets here; look at the values your account
-- produces and group them in BI or in analytics.
--
-- duration is in seconds and covers the call as Gorgias recorded it. Average
-- talk time is over answered calls only, so missed calls with a few seconds of
-- ringing do not drag it down.

WITH calls AS (
    SELECT
        c.*,
        DATE(COALESCE(c.started_at, c.created_at), tz.reporting_timezone) AS call_date,
        (c.answered_by_agent_id IS NOT NULL
         OR c.answered_by_external_number IS NOT NULL)        AS is_answered
    FROM {{ ref('stg_gorgias__voice_call') }} c
    -- Only for the time zone, set once in staging.gorgias.ticket.
    JOIN (SELECT DISTINCT gorgias_account, reporting_timezone
          FROM {{ ref('stg_gorgias__ticket') }}) tz
      ON tz.gorgias_account = c.gorgias_account
)

SELECT
    call_date                                              AS day,
    gorgias_account,
    COALESCE(direction, 'unknown')                         AS direction,
    COALESCE(status, 'unknown')                            AS status,

    COUNT(*)                                               AS calls,
    COUNTIF(is_answered)                                   AS answered_calls,
    COUNTIF(NOT is_answered)                               AS unanswered_calls,
    SAFE_DIVIDE(COUNTIF(is_answered), COUNT(*))            AS answer_rate,
    COUNTIF(has_voicemail)                                 AS calls_with_voicemail,
    COUNTIF(answered_by_external_number IS NOT NULL)       AS calls_answered_externally,
    COUNT(DISTINCT customer_id)                            AS distinct_callers,

    SUM(duration_seconds)                                  AS duration_seconds_sum,
    SUM(IF(is_answered, duration_seconds, NULL))           AS answered_duration_seconds_sum,
    AVG(IF(is_answered, duration_seconds, NULL))           AS answered_duration_seconds_avg,
    APPROX_QUANTILES(IF(is_answered, duration_seconds, NULL), 2)[SAFE_OFFSET(1)]
                                                           AS answered_duration_seconds_median
FROM calls
WHERE call_date IS NOT NULL
GROUP BY 1, 2, 3, 4
