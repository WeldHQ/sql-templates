-- core.twilio.calls_daily
-- Voice volume, outcomes, talk time and spend per day: the summary in Twilio's Voice
-- Insights and Call Logs.
--
-- Grain: one row per day (UTC, call start) x account x direction x currency.
-- Depends on: staging.twilio.call
--
-- Every call leg is a row in staging, and both legs of a forwarded call are billed, so
-- `call_legs` and `cost` count both. `parent_calls` counts only legs without a parent,
-- which is the closer match to "conversations". `direction` is `inbound`, `outbound-api`
-- or `outbound-dial` (the child leg of a <Dial>).
--
-- `billable_minutes` rounds each completed leg up to the next minute, which is how Twilio
-- bills most voice usage. SIP and some international routes are billed per second, so
-- treat it as an estimate and use `cost` for money.
-- Answer rate is completed legs over all legs; the per-row rates should be re-derived
-- from summed counts when you aggregate.

SELECT
    DATE(started_at)                                            AS date,
    account_sid,
    direction,
    currency,

    COUNT(*)                                                    AS call_legs,
    COUNTIF(parent_call_sid IS NULL)                            AS parent_calls,
    COUNTIF(status = 'completed')                               AS completed,
    COUNTIF(status = 'busy')                                    AS busy,
    COUNTIF(status = 'no-answer')                               AS no_answer,
    COUNTIF(status = 'failed')                                  AS failed,
    COUNTIF(status = 'canceled')                                AS canceled,
    COUNTIF(answered_by LIKE 'machine%')                        AS answered_by_machine,
    SAFE_DIVIDE(COUNTIF(status = 'completed'), COUNT(*))        AS answer_rate,

    SUM(duration_seconds)                                       AS talk_seconds,
    SUM(duration_seconds) / 60                                  AS talk_minutes,
    SUM(IF(status = 'completed', CEIL(duration_seconds / 60), 0)) AS billable_minutes,
    SAFE_DIVIDE(SUM(IF(status = 'completed', duration_seconds, 0)),
                COUNTIF(status = 'completed'))                  AS avg_completed_call_seconds,

    SUM(cost)                                                   AS cost
FROM {{staging.twilio.call}}
WHERE started_at IS NOT NULL
GROUP BY 1, 2, 3, 4
