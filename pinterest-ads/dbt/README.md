# Pinterest Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                                 one source, all ad accounts
models/staging/stg_pinterest_ads__*.sql                                    6 thin wrappers over the raw tables
models/core/core_pinterest_ads__ad_performance_daily.sql                   day x account x ad, cross-channel columns first
models/core/core_pinterest_ads__campaign_performance_daily.sql             day x account x campaign, with rates
models/core/core_pinterest_ads__campaign_country_performance_daily.sql     day x account x campaign x country
models/analytics/analytics__pinterest_ads_*.sql                            thin BI-facing contracts
tests/assert_pinterest_ads__ad_performance_daily_is_unique.sql             one row per day, account and ad
tests/assert_pinterest_ads__campaign_spend_ties_to_ads.sql                 campaign spend ties to ad spend
tests/assert_pinterest_ads__no_negative_delivery.sql                       no negative spend, impressions, clicks or conversions
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `models/staging/sources.yml` to wherever the
Pinterest Ads tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against Pinterest Ads Manager before relying
  on the output. See [`../README.md`](../README.md) for the conversion definition.
