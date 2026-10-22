-- core.fourth.weekly_budget_vs_actual
-- Budgeted sales and labour against actuals, per budget week, location and
-- department.
-- Grain: budget week x location x department.
--
-- Weeks are Fourth's budget weeks (week_start to week_end inclusive). Actuals
-- come from core.fourth.labour_vs_sales, summed over the days in the week, so the
-- same caveats about payroll lines apply.

WITH actuals AS (
    SELECT
        b.location_id,
        b.department_id,
        b.week_start,
        SUM(a.actual_sales)  AS actual_sales,
        SUM(a.labour_cost)   AS actual_labour_cost,
        SUM(a.labour_hours)  AS actual_labour_hours
    FROM {{staging.fourth.budget}} b
    JOIN {{core.fourth.labour_vs_sales}} a
      ON a.department_id = b.department_id
     AND a.date BETWEEN b.week_start AND b.week_end
    GROUP BY 1, 2, 3
)

SELECT
    b.week_start,
    b.week_end,
    b.location_id,
    b.location_name,
    b.department_id,
    b.department_name,
    b.sales_budget,
    ROUND(COALESCE(a.actual_sales, 0), 2)                         AS actual_sales,
    ROUND(COALESCE(a.actual_sales, 0) - b.sales_budget, 2)        AS sales_vs_budget,
    b.labour_budget_pct,
    ROUND(b.labour_budget_amount, 2)                              AS labour_budget_amount,
    ROUND(COALESCE(a.actual_labour_cost, 0), 2)                   AS actual_labour_cost,
    ROUND(COALESCE(a.actual_labour_cost, 0) - b.labour_budget_amount, 2) AS labour_vs_budget,
    SAFE_DIVIDE(a.actual_labour_cost, a.actual_sales)             AS actual_labour_pct_of_sales,
    ROUND(COALESCE(a.actual_labour_hours, 0), 2)                  AS actual_labour_hours,
    b.flex_budget
FROM {{staging.fourth.budget}} b
LEFT JOIN actuals a USING (location_id, department_id, week_start)
