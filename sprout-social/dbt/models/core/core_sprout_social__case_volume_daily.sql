-- core_sprout_social__case_volume_daily
-- Cases opened and closed per day, with the median and 90th percentile time to
-- close: Sprout's case volume and resolution trend.
--
-- Grain: date_day (UTC) x group_id x queue_id x case_type x case_priority.
-- Depends on: core.sprout_social.case_resolution
--
-- Opened is counted on the creation date, closed on the last close date, so the two
-- columns describe different cases. A case reopened and closed again is counted
-- once, on its latest close. Percentiles are per day; do not average them across
-- days, recompute from case_resolution instead.

WITH events AS (
    SELECT created_date AS date_day, customer_id, group_id, group_name, queue_id,
           case_type, case_priority, 1 AS opened, 0 AS closed, CAST(NULL AS FLOAT64) AS hours_to_close
    FROM {{ ref('core_sprout_social__case_resolution') }}
    WHERE created_date IS NOT NULL

    UNION ALL

    SELECT closed_date AS date_day, customer_id, group_id, group_name, queue_id,
           case_type, case_priority, 0 AS opened, 1 AS closed, hours_to_close
    FROM {{ ref('core_sprout_social__case_resolution') }}
    WHERE is_closed AND closed_date IS NOT NULL
)

SELECT
    date_day,
    customer_id,
    group_id,
    ANY_VALUE(group_name)                                    AS group_name,
    queue_id,
    case_type,
    case_priority,
    SUM(opened)                                              AS cases_opened,
    SUM(closed)                                              AS cases_closed,
    APPROX_QUANTILES(hours_to_close, 100 IGNORE NULLS)[SAFE_OFFSET(50)] AS median_hours_to_close,
    APPROX_QUANTILES(hours_to_close, 100 IGNORE NULLS)[SAFE_OFFSET(90)] AS p90_hours_to_close
FROM events
GROUP BY date_day, customer_id, group_id, queue_id, case_type, case_priority
