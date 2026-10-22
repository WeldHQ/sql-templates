# Google Search Console dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                      one source, all sites
models/staging/stg_google_search_console__*.sql                 4 thin wrappers over the raw tables
models/core/core_google_search_console__site_performance_daily.sql   site totals and the anonymized gap
models/core/core_google_search_console__query_performance_daily.sql  queries by day
models/core/core_google_search_console__page_performance_daily.sql   pages by day
models/core/core_google_search_console__query_page_monthly.sql       query x page split by month
models/analytics/analytics__google_search_console_*.sql         thin BI-facing contracts
tests/assert_site_performance_daily_is_unique.sql               one row per day and site
tests/assert_queries_do_not_exceed_site_totals.sql              query data is a subset of the totals
tests/assert_query_page_shares_sum_to_one.sql                   page shares of a query add to 1
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the Search Console
tables land. No vars to set.

## Notes

- Re-aggregate position with `weighted_position_sum / impressions`, never by
  averaging `average_position`.
- Not run end to end. Reconcile a month against the Search Console Performance report
  before relying on the output.
