-- stg_toast_analytics__labor_by_job
-- Thin wrapper over raw `analytics_labor_by_job`: Toast's daily labor hours and
-- cost per job. One row per restaurant x business date x job.

SELECT
    CAST(restaurant_guid AS STRING)                     AS restaurant_id,
    CAST(restaurant_name AS STRING)                     AS restaurant_name,
    COALESCE(
        SAFE.PARSE_DATE('%Y%m%d', CAST(business_date AS STRING)),
        SAFE_CAST(LEFT(CAST(business_date AS STRING), 10) AS DATE)
    )                                                   AS business_date,
    CAST(job_guid AS STRING)                            AS job_id,
    CAST(job_title AS STRING)                           AS job_title,
    CAST(job_code AS STRING)                            AS job_code,
    CAST(regular_hours AS FLOAT64)                      AS regular_hours,
    CAST(overtime_hours AS FLOAT64)                     AS overtime_hours,
    CAST(total_hours AS FLOAT64)                        AS total_hours,
    CAST(regular_cost AS FLOAT64)                       AS regular_cost,
    CAST(overtime_cost AS FLOAT64)                      AS overtime_cost,
    CAST(total_cost AS FLOAT64)                         AS total_cost
FROM {{ source('toast_analytics', 'analytics_labor_by_job') }}
WHERE restaurant_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(restaurant_guid AS STRING), CAST(business_date AS STRING), CAST(job_guid AS STRING)
    ORDER BY _weld_synced DESC
) = 1
