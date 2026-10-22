# monday.com dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                  one source
models/staging/stg_monday__*.sql            5 thin wrappers over the raw tables
models/core/core_monday__*.sql              the reports
models/analytics/analytics__monday_*.sql    thin BI-facing contracts
tests/assert_one_current_label_per_item_column.sql
tests/assert_no_duplicate_assignments.sql
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
monday.com tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a board's activity log and a few items against the
  monday.com UI before relying on the output. See [../README.md](../README.md) for
  what the connector does and does not sync.
