# Google Play dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one developer account
models/staging/stg_google_play__*.sql                       6 thin wrappers over the raw tables
models/core/core_google_play__installs_daily.sql            installs and uninstalls by country
models/core/core_google_play__store_listing_conversion.sql  visitors to acquisitions by traffic source
models/core/core_google_play__stability_by_app_version.sql  crashes and ANRs per version
models/core/core_google_play__subscriptions_daily.sql       new, canceled and active subscriptions
models/core/core_google_play__earnings_monthly.sql          charges, fees, refunds, taxes, net
models/analytics/analytics__google_play_*.sql               thin BI-facing contracts
tests/assert_earnings_buckets_sum_to_net.sql                the buckets add up to net earnings
tests/assert_installs_are_unique.sql                        one row per day, app and country
tests/assert_store_listing_reconciles.sql                   acquisitions survive the rollup
tests/assert_subscriptions_are_unique.sql                   one row per day, app, product and country
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Google Play
  tables land.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a closed month of earnings with the Play Console
  payout before relying on the output.
