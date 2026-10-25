# Snapchat Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                       one source, all ad accounts
models/staging/stg_snapchat_ads__*.sql                           5 thin wrappers over the raw tables
models/core/core_snapchat_ads__ad_performance_daily.sql          day x account x ad, cross-channel columns first
models/core/core_snapchat_ads__campaign_performance_daily.sql    day x account x campaign, with rates
models/core/core_snapchat_ads__ad_squad_performance_daily.sql    day x account x ad squad, with goal and budget
models/analytics/analytics__snapchat_ads_*.sql                   thin BI-facing contracts
tests/assert_snapchat_ads__ad_performance_daily_is_unique.sql            one row per day, account and ad
tests/assert_snapchat_ads__campaign_spend_reconciles_to_ads.sql          campaign spend and purchases tie to ads
tests/assert_snapchat_ads__no_negative_delivery.sql                      no negative spend, impressions, swipes or purchases
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the Snapchat Ads
tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against Snapchat Ads Manager before relying
  on the output. See the [main README](../README.md) for attribution and timezone
  details.
