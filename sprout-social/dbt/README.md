# Sprout Social dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, all Sprout customers
models/staging/stg_sprout_social__*.sql                     4 thin wrappers over the raw tables
models/core/core_sprout_social__message_volume_daily.sql    day x profile x post type
models/core/core_sprout_social__team_activity_daily.sql     day x user x profile
models/core/core_sprout_social__case_resolution.sql         one row per case, with timings
models/core/core_sprout_social__case_volume_daily.sql       day x group x queue x type x priority
models/analytics/analytics__sprout_social_*.sql             thin BI-facing contracts
tests/assert_case_resolution_is_unique.sql                  one row per case
tests/assert_team_activity_reconciles_to_volume.sql         per-user sends tie to the volume model
tests/assert_cases_close_after_open.sql                     no case closes before it opens
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Sprout Social
  tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against Sprout Social's reports before
  relying on the output.
