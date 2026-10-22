# Linear dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                   one source
models/staging/stg_linear__issue.sql         thin wrapper over raw issues
models/core/core_linear__*.sql               the reports
models/analytics/analytics__linear_*.sql     thin BI-facing contracts
tests/assert_flow_matches_issue_counts.sql   completions counted exactly once
tests/assert_cycle_time_not_negative.sql     no completion before creation or start
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Linear tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a team's monthly completions and cycle time with
  Linear Insights before relying on the output.
