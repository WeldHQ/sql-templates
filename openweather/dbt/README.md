# OpenWeather dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                      one source
models/staging/stg_openweather__*.sql           2 thin wrappers over the raw tables
models/core/core_openweather__*.sql             daily weather and daily forecast
models/analytics/analytics__openweather_*.sql   thin BI-facing contracts
tests/assert_one_row_per_location_day.sql       no duplicate location-days
tests/assert_forecast_days_not_overfull.sql     at most 8 steps per local day
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
OpenWeather tables.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end.
