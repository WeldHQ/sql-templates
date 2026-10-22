-- staging.fourth.sales
-- Thin wrapper over raw `sales`: actual and forecast sales per department, sales
-- type and day, as Fourth Team Hours holds them (typically fed from the EPOS).
-- One row per department x sales type x day, which is the raw table's key.
--
-- system_forecast is Fourth's own forecast; manager_forecast_sales is the
-- manager's override. Amounts are in the location's currency.

SELECT
    CAST(department_id AS STRING)               AS department_id,
    CAST(department_name AS STRING)             AS department_name,
    CAST(type_id AS STRING)                     AS sales_type_id,
    CAST(type_name AS STRING)                   AS sales_type_name,
    DATE(date)                                  AS date,
    CAST(actual_sales AS FLOAT64)               AS actual_sales,
    CAST(actual_items AS FLOAT64)               AS actual_items,
    CAST(system_forecast AS FLOAT64)            AS system_forecast_sales,
    CAST(system_forecast_items AS FLOAT64)      AS system_forecast_items,
    CAST(manager_forecast_sales AS FLOAT64)     AS manager_forecast_sales,
    CAST(manager_forecast_items AS FLOAT64)     AS manager_forecast_items
FROM {{raw.fourth.sales}}
WHERE department_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(department_id AS STRING), CAST(type_id AS STRING), DATE(date)
    ORDER BY _weld_synced DESC
) = 1
