# Asana dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                 one source
models/staging/stg_asana__*.sql            6 thin wrappers over the raw tables
models/core/core_asana__*.sql              the reports
models/analytics/analytics__asana_*.sql    thin BI-facing contracts
tests/assert_task_completion_unique.sql    no duplicate rows at the stated grain
tests/assert_project_task_counts_add_up.sql completed + open = all tasks
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Asana tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Check a project and a person against the Asana UI before
  relying on the output. See [../README.md](../README.md) for what the connector
  does not sync, starting with unassigned tasks.
