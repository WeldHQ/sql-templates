# Sona dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                       one source, one Sona organisation
models/staging/stg_sona__*.sql                   7 thin wrappers over the raw tables
models/core/core_sona__shift_coverage_daily.sql  planned, filled, agency and open shifts
models/core/core_sona__absence_daily.sql         absence days by type and location
models/core/core_sona__paid_hours_daily.sql      paid hours by pay type and location
models/analytics/analytics__sona_*.sql           thin BI-facing contracts
tests/assert_shift_statuses_add_up.sql           filled + agency + open = all shifts
tests/assert_no_negative_hours.sql               no negative shift or paid hours
tests/assert_absence_days_reconcile.sql          every absence day counted once
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Sona tables land.
- **Soft deletes on `shifts` and `pay_lines`,** or remove the `_weld_deleted_at`
  filter in their staging models.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a week of shifts with the Sona rota before relying on
  the output.
