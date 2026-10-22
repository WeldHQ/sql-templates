# TikTok Organic dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                      one source, all accounts
models/staging/stg_tiktok_organic__*.sql                        3 thin wrappers over the raw tables
models/core/core_tiktok_organic__profile_performance_daily.sql  followers, views and engagement per day
models/core/core_tiktok_organic__video_performance.sql          lifetime metrics and engagement rate per video
models/analytics/analytics__tiktok_organic_*.sql                thin BI-facing contracts
tests/assert_profile_performance_daily_is_unique.sql            one row per day and account
tests/assert_video_performance_is_unique.sql                    one row per video
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the TikTok Organic
tables land. No vars to set.

## Notes

- `followers` is a running total: take the last day of a period, never the sum.
- Not run end to end. Reconcile a week against TikTok Analytics before relying
  on the output.
