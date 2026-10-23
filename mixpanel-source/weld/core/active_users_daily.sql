-- core.mixpanel_source.active_users_daily
-- Daily, weekly and monthly active users and stickiness, per day: the DAU/WAU/MAU view
-- from Mixpanel's Insights and its "Active users" template.
--
-- Grain: one row per day (UTC).
-- Depends on: staging.mixpanel_source.events
--
-- A user is active on a day if they sent any event that day. WAU and MAU are rolling
-- windows ending on the row's day: 7 and 28 days, Mixpanel's defaults. Stickiness is
-- DAU / MAU.
--
-- Built by expanding each user's active days onto the windows they fall in, then
-- counting distinct users per window, so a user active on several days of a window counts
-- once. The first 27 days after your earliest synced event have incomplete windows;
-- `is_full_window` is false on those rows.
--
-- `new_users` are users whose first event in the synced history falls on the row's day,
-- and `returning_users` are the rest of that day's DAU. Before the connector has a full
-- history, a long-standing user's first synced day counts as new, so read `new_users`
-- from rows where `is_full_window` is true and treat early rows with care.
--
-- Every event counts as activity, including automatic ones like `$mp_web_page_view`.
-- To count only meaningful actions, filter event_name in the first CTE.

WITH active AS (
    SELECT DISTINCT
        DATE(event_at)                      AS date,
        distinct_id
    FROM {{staging.mixpanel_source.events}}
    WHERE distinct_id IS NOT NULL
),

user_days AS (
    SELECT
        date,
        distinct_id,
        date = MIN(date) OVER (PARTITION BY distinct_id) AS is_first_day
    FROM active
),

days AS (
    SELECT DISTINCT date FROM user_days
),

first_day AS (
    SELECT MIN(date) AS first_date FROM user_days
)

SELECT
    d.date,
    COUNT(DISTINCT IF(u.date = d.date, u.distinct_id, NULL))                         AS dau,
    COUNT(DISTINCT IF(u.date > DATE_SUB(d.date, INTERVAL 7 DAY), u.distinct_id, NULL)) AS wau,
    COUNT(DISTINCT u.distinct_id)                                                    AS mau,
    COUNT(DISTINCT IF(u.date = d.date AND u.is_first_day, u.distinct_id, NULL))      AS new_users,
    COUNT(DISTINCT IF(u.date = d.date AND NOT u.is_first_day, u.distinct_id, NULL))  AS returning_users,
    SAFE_DIVIDE(
        COUNT(DISTINCT IF(u.date = d.date, u.distinct_id, NULL)),
        COUNT(DISTINCT u.distinct_id))                                               AS dau_mau_stickiness,
    d.date >= DATE_ADD(ANY_VALUE(f.first_date), INTERVAL 27 DAY)                     AS is_full_window
FROM days d
CROSS JOIN first_day f
JOIN user_days u
  ON u.date > DATE_SUB(d.date, INTERVAL 28 DAY)
 AND u.date <= d.date
GROUP BY d.date
