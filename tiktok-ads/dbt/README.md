# TikTok Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                      one source, all advertisers
models/staging/stg_tiktok_ads__*.sql                            5 thin wrappers over the raw tables
models/core/core_tiktok_ads__ad_performance_daily.sql           day x advertiser x ad, cross-channel columns first
models/core/core_tiktok_ads__campaign_performance_daily.sql     day x advertiser x campaign, with rates
models/core/core_tiktok_ads__ad_group_performance_daily.sql     day x advertiser x ad group, with optimisation goal
models/analytics/analytics__tiktok_ads_*.sql                    thin BI-facing contracts
tests/assert_tiktok_ads__ad_performance_daily_is_unique.sql           one row per day, advertiser and ad
tests/assert_tiktok_ads__campaign_spend_reconciles_to_ads.sql         campaign spend and conversions tie to ads
tests/assert_tiktok_ads__no_negative_delivery.sql                     no negative spend, impressions, clicks or conversions
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the TikTok Ads
tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against TikTok Ads Manager before relying on
  the output. See the [main README](../README.md) for what `conversions` and
  `conversion_value` count.
