# Fourth templates

Wage percentage, forecast accuracy, budget tracking and staffing accuracy for
hospitality operators on Fourth (Team Hours and HR). BigQuery.

Weld connector: **Fourth** ([docs](https://weld.app/docs/applications/fourth)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/labour_vs_sales.sql`](weld/core/labour_vs_sales.sql) · [dbt](dbt/models/core/core_fourth__labour_vs_sales.sql) | Labour cost % of sales, sales per labour hour | date × department |
| [`weld/core/labour_cost_daily.sql`](weld/core/labour_cost_daily.sql) · [dbt](dbt/models/core/core_fourth__labour_cost_daily.sql) | Labour hours and cost by pay part and status | date × department × payroll type × pay part × status |
| [`weld/core/sales_forecast_accuracy.sql`](weld/core/sales_forecast_accuracy.sql) · [dbt](dbt/models/core/core_fourth__sales_forecast_accuracy.sql) | System and manager forecast vs actual sales | date × department × sales type |
| [`weld/core/weekly_budget_vs_actual.sql`](weld/core/weekly_budget_vs_actual.sql) · [dbt](dbt/models/core/core_fourth__weekly_budget_vs_actual.sql) | Sales and labour budget vs actual | budget week × location × department |
| [`weld/core/staffing_accuracy.sql`](weld/core/staffing_accuracy.sql) · [dbt](dbt/models/core/core_fourth__staffing_accuracy.sql) | Hours correctly, under and over staffed | date × location |

`weld/core/department_location.sql` is a helper: sales and payroll carry only a
department, and this map from the rota and budget streams rolls them up to a
location.

## Layers

```
raw.fourth.*           ELT output, untouched
  ↓
weld/staging/*.sql     5 thin wrappers: cast, rename, keep the latest read of each day
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.fourth.payroll}}` expects the model in a `staging > fourth` folder.

## Required tables

| Model | Raw tables |
|---|---|
| labour vs sales | `sales`, `payroll`, plus `shift` and/or `budget` for locations |
| labour cost daily | `payroll`, plus `shift` and/or `budget` for locations |
| sales forecast accuracy | `sales`, plus `shift` and/or `budget` for locations |
| weekly budget vs actual | `budget`, `sales`, `payroll`, `shift` |
| staffing accuracy | `labour_daily_summary` |

## Schema notes

- **Payroll and rota rows are re-keyed when they change.** The raw `payroll` table
  is keyed on department, employee, date, type, pay part, status and hours; `shift`
  on location, department, employee and start and end time. Edit an hour or move a
  shift and Fourth's new version arrives as a new row while the old one stays.
  Every sync re-reads whole days, so staging keeps only the rows from the latest
  read of each department-day (payroll) or location-department-day (shift). Summing
  the raw tables directly overstates labour.
- **Payroll labels are account-specific.** `type`, `pay_part` and `status` hold
  Fourth's own labels and Fourth does not publish the list. `labour_vs_sales` sums
  every payroll line. Check the distinct values in `labour_cost_daily` first, and
  filter in the `labour` CTE of `labour_vs_sales` if some lines (for example
  unapproved ones, or holiday pay you account for elsewhere) should not count.
- **Labour budget percentage is read as a percentage** (25 = 25%) and applied to the
  sales budget to give `labour_budget_amount`. Verify one week against Fourth.
- **Forecast streams are separate.** `sales_forecast`, `payroll_forecast` and
  `shift_forecast` cover today onwards and are re-pulled in full; they are not used
  here, since `sales` already carries the forecasts for past days.
- **Departments without a location.** Sales and payroll have no location column.
  Departments that never appear in the rota or the budget have location NULL.
- The HR streams (employee, employment, absences, payslips) are available but not
  used. Payslip and bank detail tables hold sensitive data; restrict access to them
  in your warehouse.

## Reconciling

Nothing here has been run against a live warehouse. Pick one location and one
week and compare actual sales, labour cost and wage percentage with the same week
in Fourth before relying on the output.

[Fourth](https://www.fourth.com/)
