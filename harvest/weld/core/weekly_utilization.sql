-- core.harvest.weekly_utilization
-- Hours against capacity per person per week: Harvest's Team report and
-- utilization numbers.
-- Grain: week x user.
--
-- Weeks start on the day set in your Harvest account (company.week_start_day),
-- so they line up with Harvest's own weekly views. Capacity is the user's CURRENT
-- weekly capacity; Harvest does not keep a history of it, so a change to someone's
-- capacity restates past weeks.
--
-- A person with no time tracked in a week has no row for that week. Utilization is
-- therefore only shown for weeks with tracked time; build a calendar spine if you
-- need zero weeks to show.

WITH settings AS (
    SELECT
        CASE LOWER(week_start_day)
            WHEN 'sunday'   THEN 1
            WHEN 'saturday' THEN 7
            ELSE 2  -- Monday, Harvest's default
        END AS week_start_dow
    FROM {{staging.harvest.company}}
),

entries AS (
    SELECT
        DATE_SUB(t.spent_date, INTERVAL MOD(EXTRACT(DAYOFWEEK FROM t.spent_date) - s.week_start_dow + 7, 7) DAY) AS week_start,
        t.user_id,
        t.rounded_hours,
        t.is_billable
    FROM {{staging.harvest.time_entry}} t
    CROSS JOIN settings s
)

SELECT
    e.week_start,
    e.user_id,
    u.user_name,
    u.is_contractor,
    u.is_active,
    ROUND(SUM(e.rounded_hours), 4)                                  AS tracked_hours,
    ROUND(SUM(IF(e.is_billable, e.rounded_hours, 0)), 4)            AS billable_hours,
    ROUND(SUM(IF(e.is_billable, 0, e.rounded_hours)), 4)            AS non_billable_hours,
    ANY_VALUE(u.weekly_capacity_hours)                              AS capacity_hours,
    SAFE_DIVIDE(SUM(e.rounded_hours), ANY_VALUE(u.weekly_capacity_hours))                   AS utilization,
    SAFE_DIVIDE(SUM(IF(e.is_billable, e.rounded_hours, 0)), ANY_VALUE(u.weekly_capacity_hours)) AS billable_utilization
FROM entries e
LEFT JOIN {{staging.harvest.user}} u ON u.user_id = e.user_id
GROUP BY 1, 2, 3, 4, 5
