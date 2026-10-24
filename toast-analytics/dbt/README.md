# Toast Analytics dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                            one source
models/staging/stg_toast_analytics__*.sql             5 thin wrappers over the raw tables
models/core/core_toast_analytics__*.sql               the reports
models/analytics/analytics__toast_analytics_*.sql     thin BI-facing contracts
tests/assert_toast_analytics__daily_sales_unique.sql                   one row per restaurant and day
tests/assert_toast_analytics__item_shares_sum_to_one.sql               item shares add up per day
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Toast Analytics tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a restaurant-day with Toast Web first.
