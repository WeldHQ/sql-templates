# Fourth dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                   one source
models/staging/stg_fourth__*.sql             5 thin wrappers over the raw tables
models/core/core_fourth__*.sql               the reports and the department-location map
models/analytics/analytics__fourth_*.sql     thin BI-facing contracts
tests/assert_labour_cost_reconciles.sql      same labour cost in both labour models
tests/assert_one_row_per_department_day.sql  no fan-out in labour_vs_sales
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Fourth tables.

## Notes

- Plain SQL, no macros, no vars.
- Look at the payroll type, pay part and status values in `labour_cost_daily`
  before trusting the wage percentage; see [../README.md](../README.md).
- Not run end to end. Reconcile one location-week against Fourth first.
