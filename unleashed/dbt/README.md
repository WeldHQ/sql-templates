# Unleashed dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                     one source
models/staging/stg_unleashed__*.sql            4 thin wrappers over the raw tables
models/core/core_unleashed__*.sql              the reports
models/analytics/analytics__unleashed_*.sql    thin BI-facing contracts
tests/assert_margin_reconciles_to_orders.sql   line revenue = order sub totals
tests/assert_stock_position_unique.sql         one row per product
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Unleashed tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a month of completed sales against Unleashed's
  Sales Enquiry first.
