# Google Ads dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                       one source, all accounts
models/staging/stg_google_ads__*.sql                             8 thin wrappers over the raw tables
models/core/core_google_ads__ad_performance_daily.sql            day x account x ad, cross-channel columns first
models/core/core_google_ads__campaign_performance_daily.sql      day x account x campaign, from the campaign report
models/core/core_google_ads__country_performance_daily.sql       day x account x campaign x country x location type
models/core/core_google_ads__landing_page_performance_daily.sql  day x account x campaign x landing page
models/analytics/analytics__google_ads_*.sql                     thin BI-facing contracts
tests/assert_google_ads__ad_performance_daily_is_unique.sql      one row per day, account, ad group and ad
tests/assert_google_ads__ad_spend_within_campaign_spend.sql      ad spend never exceeds campaign spend
tests/assert_google_ads__no_negative_delivery.sql                no negative spend, impressions or clicks
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Google Ads
  tables land.
- **The streams** listed under [Required tables](../README.md#required-tables).

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a week against the Google Ads UI before relying
  on the output.
