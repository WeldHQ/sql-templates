-- core_fourth__sales_forecast_accuracy
-- How close Fourth's system forecast and the manager's forecast came to actual
-- sales, per day, department and sales type. Forecasts drive the rota, so a
-- forecast that runs high is labour cost spent on empty tables.
-- Grain: date x department x sales type.
--
-- Errors are carried as absolute amounts so they can be summed. Weighted absolute
-- percentage error over any period is SUM(abs_error) / SUM(actual_sales); bias is
-- SUM(forecast - actual) / SUM(actual_sales). Days with no actual sales yet
-- (today, the future) are excluded.

SELECT
    s.date,
    dl.location_id,
    dl.location_name,
    s.department_id,
    s.department_name,
    s.sales_type_id,
    s.sales_type_name,
    s.actual_sales,
    s.system_forecast_sales,
    s.manager_forecast_sales,
    s.system_forecast_sales - s.actual_sales                  AS system_forecast_error,
    ABS(s.system_forecast_sales - s.actual_sales)             AS system_forecast_abs_error,
    s.manager_forecast_sales - s.actual_sales                 AS manager_forecast_error,
    ABS(s.manager_forecast_sales - s.actual_sales)            AS manager_forecast_abs_error,
    s.actual_items,
    s.system_forecast_items,
    s.manager_forecast_items
FROM {{ ref('stg_fourth__sales') }} s
LEFT JOIN {{ ref('core_fourth__department_location') }} dl USING (department_id)
WHERE s.actual_sales IS NOT NULL
  AND s.date < CURRENT_DATE()
