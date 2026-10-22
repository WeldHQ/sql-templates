# Reddit Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                 one source, all ad accounts
models/staging/stg_reddit_ads__*.sql                       5 thin wrappers over the raw tables
models/core/core_reddit_ads__ad_performance_daily.sql       day x account x ad, cross-channel columns first
models/core/core_reddit_ads__campaign_performance_daily.sql day x account x campaign, with rates
models/analytics/analytics__reddit_ads_*.sql               thin BI-facing contracts
tests/assert_ad_performance_daily_is_unique.sql            one row per day, account and ad
tests/assert_campaign_spend_reconciles_to_ads.sql          campaign spend ties to ad spend
tests/assert_no_negative_delivery.sql                      no negative spend, impressions or clicks
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Reddit Ads
  tables land.
- **The `ad_performance` custom report,** set up as described in the
  [main README](../README.md#set-up-the-report).

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against Reddit Ads Manager before relying on
  the output.
