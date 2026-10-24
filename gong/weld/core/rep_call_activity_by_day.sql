-- core.gong.rep_call_activity_by_day
-- Calls per rep per day: how many, how long, external versus internal, inbound
-- versus outbound. The activity half of Gong's Team Stats.
--
-- Grain: day x gong_account x rep (primary user).
-- Depends on: core.gong.calls, staging.gong.user
--
-- A call counts for its primary user only. A call with two reps on it is in one
-- rep's row, so summing across reps gives the true call count.
--
-- TIME ZONE: days are cut in UTC. Change the 'UTC' literal below to your reporting
-- zone if late-afternoon calls in the Americas land on the next day.
--
-- Built on a spine of every rep who is active or has ever owned a call x every day
-- from the first call to today, so a rep's quiet day is a row of zeros rather than
-- a gap a line chart would interpolate over.

WITH params AS (
    SELECT 'UTC' AS tz
),

daily AS (
    SELECT
        c.gong_account,
        COALESCE(c.primary_user_id, 'unknown')                    AS user_id,
        DATE(c.started_at, p.tz)                                  AS date,
        COUNT(*)                                                  AS calls,
        COUNTIF(c.scope = 'External')                             AS external_calls,
        COUNTIF(c.scope = 'Internal')                             AS internal_calls,
        COUNTIF(c.direction = 'Inbound')                          AS inbound_calls,
        COUNTIF(c.direction = 'Outbound')                         AS outbound_calls,
        COUNTIF(c.direction = 'Conference')                       AS conference_calls,
        SUM(COALESCE(c.duration_seconds, 0)) / 60.0               AS call_minutes,
        SUM(IF(c.scope = 'External', COALESCE(c.duration_seconds, 0), 0)) / 60.0
                                                                  AS external_call_minutes,
        COUNTIF(c.crm_deal_ids IS NOT NULL)                       AS calls_linked_to_deal
    FROM {{core.gong.calls}} c
    CROSS JOIN params p
    WHERE c.started_at IS NOT NULL
    GROUP BY 1, 2, 3
),

reps AS (
    SELECT gong_account, user_id FROM daily
    UNION DISTINCT
    SELECT gong_account, user_id FROM {{staging.gong.user}} WHERE is_active
),

date_spine AS (
    SELECT date
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(date) FROM daily),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS date
)

SELECT
    d.date,
    r.gong_account,
    r.user_id,
    u.user_name,
    u.email_address,
    u.manager_id,
    m.user_name                                 AS manager_name,
    u.is_active,
    COALESCE(a.calls, 0)                        AS calls,
    COALESCE(a.external_calls, 0)               AS external_calls,
    COALESCE(a.internal_calls, 0)               AS internal_calls,
    COALESCE(a.inbound_calls, 0)                AS inbound_calls,
    COALESCE(a.outbound_calls, 0)               AS outbound_calls,
    COALESCE(a.conference_calls, 0)             AS conference_calls,
    COALESCE(a.call_minutes, 0)                 AS call_minutes,
    COALESCE(a.external_call_minutes, 0)        AS external_call_minutes,
    COALESCE(a.calls_linked_to_deal, 0)         AS calls_linked_to_deal
FROM reps r
CROSS JOIN date_spine d
LEFT JOIN daily a
    ON  a.gong_account = r.gong_account
    AND a.user_id      = r.user_id
    AND a.date         = d.date
LEFT JOIN {{staging.gong.user}} u
    ON  u.gong_account = r.gong_account AND u.user_id = r.user_id
LEFT JOIN {{staging.gong.user}} m
    ON  m.gong_account = u.gong_account AND m.user_id = u.manager_id
