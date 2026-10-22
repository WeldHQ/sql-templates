# HiBob dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                 one source
models/staging/stg_hibob__*.sql            5 thin wrappers over the raw tables
models/core/core_hibob__*.sql              the reports
models/analytics/analytics__hibob_*.sql    thin BI-facing contracts
tests/assert_headcount_identity.sql        end = start + hires - leavers on every row
tests/assert_headcount_carries_over.sql    each month starts where the last ended
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
HiBob tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a month's headcount with HiBob's own report before
  relying on the output.
