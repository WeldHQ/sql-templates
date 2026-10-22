-- core_sona__paid_hours_daily
-- Paid hours per day as Sona sends them to payroll, by location and pay type: the
-- hours side of a labour cost report.
--
-- Grain: one row per local pay date x home org unit x pay type x entry type.
-- Depends on: staging.sona.pay_lines, staging.sona.users, staging.sona.org_units
--
-- Pay lines carry a user but no location, so each line is placed on the user's
-- administrative (home) org unit and dated in that unit's time zone. Someone who
-- covers a shift elsewhere still counts at home here; use shift_coverage_daily for
-- hours by where the work happened.
--
-- Cost is not computed: Sona returns hourly and annual rates in the same field, so
-- multiplying hours by rate is only right for part of the lines. Join your own rate
-- table if you need cost.

SELECT
    DATE(p.starts_at, COALESCE(o.timezone, 'UTC'))  AS pay_date,
    u.home_org_unit_id                              AS org_unit_id,
    ANY_VALUE(o.org_unit_name)                      AS org_unit_name,
    p.pay_type,
    p.entry_type,

    COUNT(*)                                        AS pay_lines,
    COUNT(DISTINCT p.user_id)                       AS people_paid,
    ROUND(SUM(p.duration_minutes) / 60.0, 2)        AS paid_hours
FROM {{ ref('stg_sona__pay_lines') }} p
LEFT JOIN {{ ref('stg_sona__users') }} u
  ON u.user_id = p.user_id
LEFT JOIN {{ ref('stg_sona__org_units') }} o
  ON o.org_unit_id = u.home_org_unit_id
GROUP BY pay_date, u.home_org_unit_id, p.pay_type, p.entry_type
