# Harvest templates

Four reports for a services business on Harvest: where the hours went, how
utilised each person is, how each project is doing against budget, and who owes
you money. BigQuery.

Weld connector: **Harvest** ([docs](https://weld.app/docs/applications/harvest)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/time_report.sql`](weld/core/time_report.sql) · [dbt](dbt/models/core/core_harvest__time_report.sql) | Time report: hours, billable amount, cost | day × user × project × task |
| [`weld/core/weekly_utilization.sql`](weld/core/weekly_utilization.sql) · [dbt](dbt/models/core/core_harvest__weekly_utilization.sql) | Team report: hours vs capacity | week × user |
| [`weld/core/project_budget.sql`](weld/core/project_budget.sql) · [dbt](dbt/models/core/core_harvest__project_budget.sql) | Project Budget report, plus revenue, cost and profit | project |
| [`weld/core/invoice_aging.sql`](weld/core/invoice_aging.sql) · [dbt](dbt/models/core/core_harvest__invoice_aging.sql) | Outstanding Invoices, plus days to pay | invoice |

## Layers

```
raw.harvest.*          ELT output, untouched
  ↓
weld/staging/*.sql     8 thin wrappers: cast, rename, keep the latest version, seconds to hours
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.harvest.time_entry}}` expects the model in a `staging > harvest` folder.

## Required tables

| Model | Raw tables |
|---|---|
| time report | `time_entry`, `company` |
| weekly utilization | `time_entry`, `user`, `company` |
| project budget | `project`, `project_budget_report`, `time_entry`, `expense`, `invoice`, `invoice_line_items`, `company` |
| invoice aging | `invoice` |

## Money and units

- **Billable amounts use rounded hours**, as Harvest does on invoices and in its
  reports. `rounded_hours` follows your account's time rounding setting and equals
  `hours` when rounding is off. Cost uses tracked `hours`; switch to
  `rounded_hours` in `time_report` and `project_budget` if you want cost rounded too.
- **Two currencies.** Billable rates, expenses and invoices are in the client's
  currency; cost rates are in the account's currency. Every model carries the
  currency next to the amount. `project_budget.profit` is NULL when the two
  differ, rather than subtracting one currency from another.
- **Capacity is in seconds in the API.** `user.weekly_capacity` is stored as
  seconds (126000 = 35 hours) and converted to hours in staging.
- **Weeks start on your account's week start day** (`company.week_start_day`).

## Schema notes

- **Deleted time entries stay in the warehouse.** The stream is incremental on
  Harvest's `updated_since` filter, which never returns deletions. An entry deleted
  in Harvest keeps counting here. If totals drift above Harvest's, compare against
  the `time_projects_report` table, which the connector re-pulls per day for the
  last year and therefore reflects deletions, and consider a periodic full
  refresh of `time_entry`.
- **Capacity history is not kept.** Harvest stores only a person's current weekly
  capacity, so a capacity change restates past utilization.
- **Budget columns are Harvest's own** (`project_budget_report`, re-pulled in full
  each sync). They are in the unit of `budget_by`: hours for `project` and `task`,
  money for `project_cost` and `task_fees`. Monthly budgets cover the current
  month only, while the hours and money columns next to them are all-time.
- **Invoiced amount per project** sums line items that carry a project, on open and
  paid invoices. Lines without a project (for example a manual discount line) are
  not attributed.

## Reconciling

Nothing here has been run against a live warehouse. Before relying on it:

- Run Harvest's Time report for last month, grouped by project, and compare hours
  and billable amount with `time_report` for the same dates.
- Compare one project's budget spent with its Harvest project page.
- Compare `invoice_aging` totals per currency, `state = 'open'`, with Harvest's
  Outstanding invoices list.

[Harvest API v2](https://help.getharvest.com/api-v2/) ·
[time entries](https://help.getharvest.com/api-v2/timesheets-api/timesheets/time-entries/) ·
[reports](https://help.getharvest.com/api-v2/reports-api/reports/time-reports/)
