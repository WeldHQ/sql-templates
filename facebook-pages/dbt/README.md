# Facebook Pages dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                    one source, all Pages
models/staging/stg_facebook_pages__*.sql                      4 thin wrappers over the raw tables
models/core/core_facebook_pages__page_performance_daily.sql   followers, views and engagement per day
models/core/core_facebook_pages__post_performance.sql         lifetime metrics and engagement rate per post
models/analytics/analytics__facebook_pages_*.sql              thin BI-facing contracts
tests/assert_page_performance_daily_is_unique.sql             one row per day and Page
tests/assert_post_performance_is_unique.sql                   one row per post
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the Facebook Pages
tables land. With more than one Page, add each `<page_name>__<page_id>__post` and
`__post_lifetime_insights` table to `sources.yml` and union them in the two
staging models.

## Notes

- `followers` is a running total: take the last day of a period, never the sum.
- Not run end to end. Reconcile a month against Page Insights before relying on
  the output.
