# YouTube Analytics dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                     one source, all channels
models/staging/stg_youtube_analytics__*.sql                    4 thin wrappers over the raw reports
models/core/core_youtube_analytics__channel_performance_daily.sql  channel totals by day
models/core/core_youtube_analytics__video_performance_daily.sql    per video by day
models/core/core_youtube_analytics__traffic_sources_daily.sql      views by traffic source
models/core/core_youtube_analytics__viewer_demographics_daily.sql  views by age group and gender
models/analytics/analytics__youtube_analytics_*.sql            thin BI-facing contracts
tests/assert_youtube_analytics__video_performance_daily_is_unique.sql             one row per day, channel and video
tests/assert_youtube_analytics__traffic_sources_reconcile_to_channel_views.sql    two reports agree on monthly views
tests/assert_youtube_analytics__no_negative_activity.sql                          no negative views or watch time
tests/assert_youtube_analytics__viewer_demographic_shares_sum_to_one.sql          age and gender shares add up per day
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the YouTube tables
land. No vars to set.

## Notes

- Re-aggregate averages from the weighted sums, never by averaging the averages.
- Not run end to end. Reconcile a closed month against YouTube Studio before relying
  on the output.
