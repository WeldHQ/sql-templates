-- core.fourth.labour_vs_sales
-- Labour cost as a share of sales, and sales per labour hour, per day and
-- department. The headline wage-percentage view in Fourth.
-- Grain: date x department.
--
-- Sales are summed over every sales type; labour over every payroll line. If
-- your payroll carries lines that should not count towards wage cost (see
-- core.fourth.labour_cost_daily for the types, pay parts and statuses present),
-- filter them in the labour CTE below.
--
-- Ratios are computed per row. To roll up to a week, a location or the estate,
-- sum labour_cost and actual_sales first and divide, never average the
-- percentages.

WITH sales AS (
    SELECT
        date,
        department_id,
        ANY_VALUE(department_name)        AS department_name,
        SUM(actual_sales)                 AS actual_sales,
        SUM(system_forecast_sales)        AS system_forecast_sales,
        SUM(manager_forecast_sales)       AS manager_forecast_sales
    FROM {{staging.fourth.sales}}
    GROUP BY 1, 2
),

labour AS (
    SELECT
        date,
        department_id,
        ANY_VALUE(department_name)        AS department_name,
        SUM(hours)                        AS labour_hours,
        SUM(pay_value)                    AS labour_cost
    FROM {{staging.fourth.payroll}}
    GROUP BY 1, 2
)

SELECT
    COALESCE(s.date, l.date)                                  AS date,
    dl.location_id,
    dl.location_name,
    COALESCE(s.department_id, l.department_id)                AS department_id,
    COALESCE(s.department_name, l.department_name)            AS department_name,
    ROUND(COALESCE(s.actual_sales, 0), 2)                     AS actual_sales,
    ROUND(COALESCE(s.system_forecast_sales, 0), 2)            AS system_forecast_sales,
    ROUND(COALESCE(s.manager_forecast_sales, 0), 2)           AS manager_forecast_sales,
    COALESCE(l.labour_hours, 0)                    AS labour_hours,
    COALESCE(l.labour_cost, 0)                    AS labour_cost,
    SAFE_DIVIDE(l.labour_cost, s.actual_sales)                AS labour_pct_of_sales,
    SAFE_DIVIDE(s.actual_sales, l.labour_hours)               AS sales_per_labour_hour
FROM sales s
FULL OUTER JOIN labour l USING (date, department_id)
LEFT JOIN {{core.fourth.department_location}} dl
       ON dl.department_id = COALESCE(s.department_id, l.department_id)
