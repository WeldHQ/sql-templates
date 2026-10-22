# HiBob templates

Three people reports from HiBob: headcount and turnover over time, time off by
day, and a clean employee roster. BigQuery.

Weld connector: **HiBob** ([docs](https://weld.app/docs/applications/hibob)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/headcount_monthly.sql`](weld/core/headcount_monthly.sql) · [dbt](dbt/models/core/core_hibob__headcount_monthly.sql) | Headcount, hires, leavers, turnover | month × department × site |
| [`weld/core/time_off_daily.sql`](weld/core/time_off_daily.sql) · [dbt](dbt/models/core/core_hibob__time_off_daily.sql) | Who's out, and time off taken by policy | date × employee × policy type × status |
| [`weld/core/employee_roster.sql`](weld/core/employee_roster.sql) · [dbt](dbt/models/core/core_hibob__employee_roster.sql) | People directory with tenure and recent time off | employee |

Compensation fields are synced by the connector but deliberately left out of
these models. Add them in your own model if your warehouse permissions allow it.

## Layers

```
raw.hibob.*            ELT output, untouched
  ↓
weld/staging/*.sql     5 thin wrappers: cast, rename, pick the readable form of each field
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.hibob.employee}}` expects the model in a `staging > hibob` folder.

## Required tables

| Model | Raw tables |
|---|---|
| headcount monthly | `employee`, `employee_work_history`, `entity_names` |
| time off daily | `time_off`, `timeoff_durations`, `employee` |
| employee roster | `employee`, `time_off`, `timeoff_durations` |

## How headcount is counted

- A person is in the headcount from their start date up to and including their
  termination date, which HiBob records as the last day worked.
- Department and site are taken from work history as of the month end, or the
  termination date for leavers. HiBob stores the department as an id from its
  department list; `entity_names` turns it into a name.
- Each person-month sits in one department, so on every row
  `headcount_end = headcount_start + hires - leavers`. A move between departments
  shows as a drop in one and a rise in the other, with no hire or leaver.
- `turnover_rate` is leavers divided by the average of start and end headcount for
  the month. Annualise or sum over a window in BI from the raw columns, not by
  adding rates.
- Voluntary and involuntary leavers are split on HiBob's termination type text.
  If your account uses other labels, adjust the two `LIKE` conditions.

## Schema notes

- **Rehires count once.** HiBob keeps one record per person and `start_date` is the
  start of the current employment. Earlier employment periods are not rebuilt.
- **Fields come in three forms.** The people search returns each field nested,
  slash-keyed (`*_value`) and human readable (`human_readable_*`). Staging prefers
  the human-readable form for list fields, where the other two hold an id.
- **Missing permissions look like missing data.** HiBob leaves out fields the
  service user cannot read without an error. A column that is NULL for everyone
  usually means the service user lacks access to that field category.
- **Cancelled time off can linger.** Time off comes from HiBob's "who's out"
  endpoint, which returns approved and pending requests. On incremental syncs only
  dates from the last sync onwards are re-read, so a past request that is later
  cancelled or declined stays in the raw table with its last status. A periodic
  full refresh of the `time_off` stream clears them.
- **Per-day hours are what HiBob reports for the request.** The connector stores
  each request's daily breakdown in `timeoff_durations`. For day-based policies,
  check that the hours match your working pattern before summing them as days.

## Reconciling

Nothing here has been run against a live warehouse. Compare `headcount_end` for
last month with HiBob's headcount report for the same date, and one person's
approved time off with their time off tab, before relying on the output.

[HiBob API: people search](https://apidocs.hibob.com/reference/post_people-search) ·
[who's out](https://apidocs.hibob.com/reference/get_timeoff-whosout)
