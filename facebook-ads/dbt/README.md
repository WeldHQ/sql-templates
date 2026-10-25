# Facebook Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                               one source, all ad accounts
models/staging/stg_facebook_ads__*.sql                                   8 thin wrappers over the raw tables
models/core/core_facebook_ads__ad_performance_daily.sql                  day x account x ad, cross-channel columns first
models/core/core_facebook_ads__campaign_performance_daily.sql            day x account x campaign, with rates
models/core/core_facebook_ads__ad_set_performance_daily.sql              day x account x ad set, with attribution setting
models/core/core_facebook_ads__conversions_by_action_type_daily.sql      day x account x ad x action type
models/analytics/analytics__facebook_ads_*.sql                           thin BI-facing contracts
tests/assert_facebook_ads__ad_performance_daily_is_unique.sql            one row per day, account and ad
tests/assert_facebook_ads__campaign_spend_reconciles_to_ads.sql          campaign spend ties to ad spend
tests/assert_facebook_ads__purchases_match_action_breakdown.sql          purchases tie to the action type breakdown
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Facebook Ads
  tables land.
- **The streams** listed under [Required tables](../README.md#required-tables).

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against Ads Manager before relying on the
  output.
