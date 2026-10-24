# AppLovin dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                   one source, one AppLovin account
models/staging/stg_applovin__*.sql                           2 thin wrappers over the raw reports
models/core/core_applovin__ad_performance_daily.sql          day x campaign x creative set, cross-channel columns first
models/core/core_applovin__campaign_performance_daily.sql    day x campaign, with rates and cohort ROAS
models/analytics/analytics__applovin_*.sql                   thin BI-facing contracts
tests/assert_applovin__ad_performance_daily_is_unique.sql              one row per day, campaign and creative set
tests/assert_applovin__creative_set_spend_reconciles_to_campaigns.sql  the two reports agree on spend
tests/assert_applovin__no_negative_delivery.sql                        no negative spend, impressions, clicks or installs
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the AppLovin
  tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against the AppLovin dashboard, in UTC,
  before relying on the output.
