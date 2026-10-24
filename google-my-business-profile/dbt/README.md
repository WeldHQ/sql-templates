# Google Business Profile dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                              one source, all locations
models/staging/stg_google_my_business_profile__*.sql                    4 thin wrappers over the raw tables
models/core/core_google_my_business_profile__location_performance_daily.sql  daily views and actions per location
models/core/core_google_my_business_profile__search_keywords_monthly.sql     search terms per location and month
models/core/core_google_my_business_profile__reviews_monthly.sql             reviews, rating and replies per month
models/analytics/analytics__google_my_business_profile_*.sql            thin BI-facing contracts
tests/assert_google_my_business_profile__location_performance_daily_is_unique.sql                   one row per day and location
tests/assert_google_my_business_profile__review_totals_reconcile.sql                                running count ties to the review table
tests/assert_google_my_business_profile__ratings_in_range.sql                                       ratings stay between 1 and 5
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the Business Profile
tables land. No vars to set.

## Notes

- `reviews_monthly` uses `CURRENT_DATE()` to extend each location to this month, so
  it changes when the month turns even without new data.
- Not run end to end. Reconcile a month against Business Profile Manager before
  relying on the output.
