# Microsoft Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                                one source, all accounts
models/staging/stg_microsoft_ads__*.sql                                   7 thin wrappers over the raw tables
models/core/core_microsoft_ads__ad_performance_daily.sql                  day x account x ad, cross-channel columns first
models/core/core_microsoft_ads__campaign_performance_daily.sql            day x account x campaign, from the campaign report
models/core/core_microsoft_ads__ad_group_performance_daily.sql            day x account x ad group, from the ad group report
models/core/core_microsoft_ads__account_performance_daily.sql             day x account, with time zone
models/analytics/analytics__microsoft_ads_*.sql                           thin BI-facing contracts
tests/assert_microsoft_ads__ad_performance_daily_is_unique.sql            one row per day, account and ad
tests/assert_microsoft_ads__ad_spend_within_campaign_spend.sql            ad and ad group spend never exceed campaign spend
tests/assert_microsoft_ads__account_spend_reconciles_to_campaigns.sql     account spend ties to campaign spend
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Microsoft Ads
  tables land.
- **The streams** listed under [Required tables](../README.md#required-tables).

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against the Microsoft Advertising UI before
  relying on the output.
