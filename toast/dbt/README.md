# Toast dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                    one source
models/staging/stg_toast__*.sql               11 thin wrappers over the raw tables
models/core/core_toast__*.sql                 the reports
models/analytics/analytics__toast_*.sql       thin BI-facing contracts
tests/assert_toast__menu_mix_reconciles_to_sales.sql product mix sums to the sales summary
tests/assert_toast__discounts_not_negative.sql       gross is never below net
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Toast tables.

**Your overtime multiplier**, if it is not 1.5, in `core_toast__labor_by_job.sql`.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a business day against Toast's Sales Summary first.
