# eSmiley dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                    one source
models/staging/stg_esmiley__*.sql             3 thin wrappers over the raw tables
models/core/core_esmiley__*.sql               the reports and the registration point tree
models/analytics/analytics__esmiley_*.sql     thin BI-facing contracts
tests/assert_monthly_reconciles_to_daily.sql  monthly totals equal daily totals
tests/assert_no_negative_waste.sql            no negative weight or cost
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
eSmiley tables.

**A check of the units**, described in [../README.md](../README.md), before using
cost and CO2.

## Notes

- Plain SQL, no macros, no vars. The registration point tree uses a recursive CTE.
- Not run end to end.
