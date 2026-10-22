# Harvest dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                      one source
models/staging/stg_harvest__*.sql               8 thin wrappers over the raw tables
models/core/core_harvest__*.sql                 the reports
models/analytics/analytics__harvest_*.sql       thin BI-facing contracts
tests/assert_time_report_reconciles_to_utilization.sql  same hours in both models
tests/assert_invoice_due_not_above_amount.sql           0 <= due amount <= amount
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Harvest tables.

## Notes

- Plain SQL, no macros, no vars. The week start day and account currency come from
  Harvest's `company` table.
- Not run end to end. Reconcile a month against Harvest's Time report before
  relying on the output; deleted time entries are the usual cause of a difference.
