-- No negative shift or paid hours. A shift that finishes before it starts, or a
-- pay line with negative minutes, points at a time zone or parsing problem in
-- staging.

SELECT 'shift' AS source, shift_date AS date_day, planned_hours AS hours
FROM {{ ref('core_sona__shift_coverage_daily') }}
WHERE planned_hours < 0
UNION ALL
SELECT 'pay' AS source, pay_date AS date_day, paid_hours AS hours
FROM {{ ref('core_sona__paid_hours_daily') }}
WHERE paid_hours < 0
