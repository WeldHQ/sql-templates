# Cross-channel paid media dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/core/core_cross_channel_ads__campaign_performance_daily.sql   union of every platform's campaign model
models/core/core_cross_channel_ads__channel_performance_daily.sql    day x platform x currency overview
models/analytics/analytics__cross_channel_ads_*.sql                 thin BI-facing contracts
tests/assert_cross_channel_ads__campaign_grain_is_unique.sql         one row per day, platform, account, campaign
tests/assert_cross_channel_ads__channel_spend_reconciles_to_campaigns.sql   overview spend ties to campaigns
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **The platform models.** Each branch refs `core_<platform>__campaign_performance_daily`
  from that platform's folder. Copy those in first, and delete the branches for
  platforms you do not sync.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week of spend per platform against each
  platform's UI before relying on the output.
