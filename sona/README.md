# Sona templates

Rota coverage, absence and paid hours from Sona, the workforce management platform:
how many shifts were filled by your own staff or an agency, who was off and why,
and how many hours went to payroll. BigQuery.

Weld connector: **Sona** ([docs](https://weld.app/docs/applications/sona)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/shift_coverage_daily.sql`](weld/core/shift_coverage_daily.sql) · [dbt](dbt/models/core/core_sona__shift_coverage_daily.sql) | Rota coverage: planned, filled, agency and open shifts and hours, fill rate, agency share | local date × org unit × shift type |
| [`weld/core/absence_daily.sql`](weld/core/absence_daily.sql) · [dbt](dbt/models/core/core_sona__absence_daily.sql) | Absence by type and location, sickness and holiday split | date × home org unit × absence type × day status |
| [`weld/core/paid_hours_daily.sql`](weld/core/paid_hours_daily.sql) · [dbt](dbt/models/core/core_sona__paid_hours_daily.sql) | Paid hours sent to payroll, by pay type | local date × home org unit × pay type × entry type |

## Layers

```
raw.sona.*              ELT output, untouched
  ↓
weld/staging/*.sql      7 thin wrappers: cast, rename, de-duplicate, drop deleted rows
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.sona.shifts}}` expects the model
in a `staging > sona` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| shift coverage daily | `shifts`, `org_units` |
| absence daily | `absence_days`, `absences`, `absence_types`, `users`, `org_units` |
| paid hours daily | `pay_lines`, `users`, `org_units` |

## Notes

- **Deleted shifts and pay lines.** Sona changes rotas and pay after the fact, and
  the connector re-reads a window of recent (and, for shifts, upcoming) rows on
  every run, marking rows that disappeared with `_weld_deleted_at`. Staging drops
  them. If soft deletes are turned off for those streams the column does not exist;
  remove the filter line, and expect deleted shifts to stay in the counts.
- **How a shift is classed.** Agency if an agency is on it; otherwise filled if it is
  linked to an employment period or a user; otherwise open. This is read from the
  columns Sona returns, not from a status Sona documents. Check a week against the
  rota before relying on fill rates, and adjust the `CASE` in
  `shift_coverage_daily` if your rota treats some state differently.
- **Draft shifts and travel gaps are not shifts.** Draft copies are excluded;
  travel gaps between visits are reported as `travel_gap_hours` and left out of
  shift counts and fill rates.
- **Hours include breaks.** Shift hours are start to finish. Paid hours come from
  Sona's own `duration_in_minutes` on each pay line.
- **Local dates.** Shifts and pay lines are dated in the time zone of the relevant
  org unit (`org_units.timezone`, UTC if empty).
- **Home org unit.** Absences and pay lines carry a person, not a place, so they are
  reported on the person's administrative org unit. Someone covering a shift at
  another location counts at home in `paid_hours_daily` and at the shift's location
  in `shift_coverage_daily`.
- **No cost.** Sona returns hourly and annual rates in the same field, so hours x
  rate is only right for part of the lines. Join your own rates if you need cost.
- **Absence day status is part of the grain** because its values are not publicly
  documented. Filter it in the analytics layer once you have seen your values.
- **Personal data is left out of staging.** Names, contact details, date of birth
  and similar fields in `users` are not selected.
- **Rates roll up from sums.** `fill_rate` and `agency_share` are computed from the
  hour columns in the same row; to roll up, sum the hours and divide again.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare one week of shifts per location and one month of
  absence days with Sona's own reports before relying on the output.

## Schema notes

There is no public ERD for this connector; tables and columns follow the connector's
own definitions.

## Vendor docs

Sona does not publish its API reference openly, which is also why some field
values above are described as unverified. The [Weld connector docs](https://weld.app/docs/applications/sona) list
the streams and how they are read.
