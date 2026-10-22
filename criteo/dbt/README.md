# Criteo dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, all advertisers
models/staging/stg_criteo__*.sql                        5 thin wrappers over the raw tables
models/core/core_criteo__ad_performance_daily.sql       day x campaign x ad set x ad, cross-channel columns first
models/core/core_criteo__campaign_performance_daily.sql day x advertiser x campaign, with rates
models/analytics/analytics__criteo_*.sql                thin BI-facing contracts
tests/assert_ad_performance_daily_is_unique.sql         one row per day, campaign, ad set and ad
tests/assert_campaign_spend_reconciles_to_ads.sql       campaign spend ties to ad spend
tests/assert_no_negative_delivery.sql                   no negative spend, displays, clicks or sales
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Criteo tables
  land.
- **The currency and timezone** in the connector settings, matching what you use
  in the Criteo UI.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against the Criteo UI before relying on the
  output.
