# Amazon Attribution dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                          one source, all profiles
models/staging/stg_amazon_attribution__*.sql                        5 thin wrappers over the raw tables
models/core/core_amazon_attribution__creative_performance_daily.sql day x advertiser x creative, cross-channel columns first
models/core/core_amazon_attribution__campaign_performance_daily.sql day x advertiser x campaign, with rates and bonus
models/core/core_amazon_attribution__product_performance_daily.sql  day x campaign x ad group x ASIN
models/analytics/analytics__amazon_attribution_*.sql                thin BI-facing contracts
tests/assert_creative_performance_daily_is_unique.sql               one row per day and creative
tests/assert_campaign_performance_daily_is_unique.sql               one row per day and campaign
tests/assert_total_covers_promoted.sql                              total metrics never below promoted ones
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Amazon
  Attribution tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against the Amazon Attribution console before
  relying on the output.
