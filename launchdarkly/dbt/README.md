# LaunchDarkly dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one account
models/staging/stg_launchdarkly__*.sql                      4 thin wrappers over the raw tables
models/core/core_launchdarkly__flag_inventory.sql           every flag with age, state, owner, cleanup flag
models/core/core_launchdarkly__flag_health_by_project.sql   flag debt per project
models/core/core_launchdarkly__context_activity.sql         total and recently active contexts
models/analytics/analytics__launchdarkly_*.sql              thin BI-facing contracts
tests/assert_flag_inventory_is_unique.sql                   one row per project and flag
tests/assert_project_health_reconciles_to_inventory.sql     project totals add up to the inventory
tests/assert_context_recency_is_nested.sql                  1 day <= 7 days <= 30 days <= total
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the LaunchDarkly
  tables land.

## Notes

- Plain SQL, no macros, no vars.
- All three core models are snapshots measured from `CURRENT_DATE()`. Snapshot them
  daily (for example with a dbt snapshot or an incremental model) to build trends.
- Not run end to end. Compare flag counts with the LaunchDarkly Flags list before
  relying on the output.
