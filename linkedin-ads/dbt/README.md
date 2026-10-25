# LinkedIn Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                             one source, all ad accounts
models/staging/stg_linkedin_ads__*.sql                                 5 thin wrappers over the raw tables
models/core/core_linkedin_ads__ad_performance_daily.sql                day x account x creative, cross-channel columns first
models/core/core_linkedin_ads__campaign_performance_daily.sql          day x account x campaign, with rates
models/core/core_linkedin_ads__campaign_group_performance_daily.sql    day x account x campaign group, with rates
models/analytics/analytics__linkedin_ads_*.sql                         thin BI-facing contracts
tests/assert_linkedin_ads__ad_performance_daily_is_unique.sql          one row per day, account and creative
tests/assert_linkedin_ads__campaign_spend_ties_to_ads.sql              campaign spend ties to creative spend
tests/assert_linkedin_ads__no_negative_delivery.sql                    no negative spend, impressions, clicks or conversions
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `models/staging/sources.yml` to wherever the
LinkedIn Ads tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against Campaign Manager before relying on
  the output. See [`../README.md`](../README.md) for the conversion definition.
