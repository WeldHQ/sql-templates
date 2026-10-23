# LinkedIn Pages dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                   one source, all Pages
models/staging/stg_linkedin_pages__*.sql                     10 thin wrappers over the raw tables
models/core/core_linkedin_pages__page_performance_daily.sql  organic impressions and engagement per day
models/core/core_linkedin_pages__follower_growth_daily.sql   new followers and estimated total per day
models/core/core_linkedin_pages__follower_demographics.sql   follower breakdowns, current snapshot
models/analytics/analytics__linkedin_pages_*.sql             thin BI-facing contracts
tests/assert_linkedin_pages__page_performance_daily_is_unique.sql            one row per day and Page
tests/assert_linkedin_pages__follower_growth_daily_is_unique.sql             one row per day and Page
tests/assert_linkedin_pages__demographic_shares_sum_to_one.sql               segment shares of a facet add to 1
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the LinkedIn Pages
tables land. No vars to set.

## Notes

- Roll engagement rate up as `sum(engagements) / sum(impressions)`, never by
  averaging `engagement_rate`.
- `followers_estimated` is rebuilt from today's count and daily gains; see the
  model header for why it is approximate.
- Not run end to end. Reconcile a month against LinkedIn Page analytics before
  relying on the output.
