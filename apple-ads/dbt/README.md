# Apple Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one organization
models/staging/stg_apple_ads__*.sql                         2 thin wrappers over the raw tables
models/core/core_apple_ads__campaign_performance_daily.sql  day x organization x campaign, cross-channel columns first
models/core/core_apple_ads__app_performance_daily.sql       day x organization x app
models/analytics/analytics__apple_ads_*.sql                 thin BI-facing contracts
tests/assert_campaign_performance_daily_is_unique.sql       one row per day and campaign
tests/assert_app_spend_reconciles_to_campaigns.sql          app spend ties to campaign spend
tests/assert_no_negative_delivery.sql                       no negative spend, impressions, taps or installs
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Apple Ads
  tables land.

## Notes

- Plain SQL, no macros, no vars.
- Check that the install columns are filled first; see the
  [main README](../README.md#notes).
- Not run end to end. Reconcile a week against the Apple Ads UI before relying on
  the output.
