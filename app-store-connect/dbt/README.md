# App Store Connect dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                       one source, one App Store Connect account
models/staging/stg_app_store_connect__*.sql                      6 thin wrappers over the raw tables
models/core/core_app_store_connect__downloads_and_deletions.sql  installs by type, and deletions
models/core/core_app_store_connect__product_page_conversion.sql  impressions to downloads, by source
models/core/core_app_store_connect__usage_and_stability.sql      sessions and crashes per app version
models/core/core_app_store_connect__sales_and_proceeds.sql       units, sales and proceeds, refunds netted
models/core/core_app_store_connect__ratings_and_reviews.sql      written reviews and replies
models/analytics/analytics__app_store_connect_*.sql              thin BI-facing contracts
tests/assert_conversion_keeps_every_download.sql                 the funnel join loses no downloads
tests/assert_sales_units_split_adds_up.sql                       sold - refunded = net units
tests/assert_usage_is_unique.sql                                 one row per day, app, version, device
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the App Store
  Connect tables land.

## Notes

- Plain SQL, no macros, no vars.
- Currencies are part of the grain of `sales_and_proceeds`. Convert before summing.
- Not run end to end. Compare a week with Sales and Trends and App Analytics before
  relying on the output.
