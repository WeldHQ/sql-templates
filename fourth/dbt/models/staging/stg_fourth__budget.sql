-- stg_fourth__budget
-- Thin wrapper over raw `budget`: weekly sales budget and labour budget per
-- location and department. One row per location x department x week.
--
-- labour_budget_percentage is the labour budget as a percentage of sales (25 means
-- 25%), and labour_budget_amount applies it to the sales budget. Check one week
-- against Fourth before relying on that reading of the field.

SELECT
    CAST(location_id AS STRING)                 AS location_id,
    CAST(location_name AS STRING)               AS location_name,
    CAST(department_id AS STRING)               AS department_id,
    CAST(department_name AS STRING)             AS department_name,
    DATE(week_start)                            AS week_start,
    DATE(week_end)                              AS week_end,
    CAST(sales_budget AS FLOAT64)               AS sales_budget,
    CAST(labour_budget_percentage AS FLOAT64)   AS labour_budget_pct,
    CAST(sales_budget AS FLOAT64) * CAST(labour_budget_percentage AS FLOAT64) / 100 AS labour_budget_amount,
    CAST(forecast_or_actual_sales AS FLOAT64)   AS forecast_or_actual_sales,
    CAST(flex_budget AS FLOAT64)                AS flex_budget,
    CAST(flex_budget_percentage AS FLOAT64)     AS flex_budget_pct
FROM {{ source('fourth', 'budget') }}
WHERE department_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(location_id AS STRING), CAST(department_id AS STRING), DATE(week_start)
    ORDER BY _weld_synced DESC
) = 1
