# OpenWeather templates

Daily weather and a daily forecast per location, shaped to join onto sales,
covers or footfall by date. BigQuery.

Weld connector: **OpenWeather** ([docs](https://weld.app/docs/applications/openweather)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/daily_weather.sql`](weld/core/daily_weather.sql) · [dbt](dbt/models/core/core_openweather__daily_weather.sql) | What the weather was: temperatures, rain, wind, wet-day and temperature-band flags, change vs last week | date × location |
| [`weld/core/daily_forecast.sql`](weld/core/daily_forecast.sql) · [dbt](dbt/models/core/core_openweather__daily_forecast.sql) | What the next five days look like, by local day | local date × location |

Weather is rarely a report on its own. The point of these models is the join:

```sql
SELECT s.*, w.temp_max_c, w.is_wet_day, w.temp_band
FROM {{core.toast.sales_summary}} s
LEFT JOIN {{core.openweather.daily_weather}} w
  ON w.date = s.business_date
 AND w.city = 'Copenhagen'
```

Map each of your locations to the city you configured in the connector, in a small
lookup table, if you have more than one.

## Layers

```
raw.openweather.*      ELT output, untouched
  ↓
weld/staging/*.sql     2 thin wrappers: cast, rename, unix seconds to timestamps
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.openweather.daily_weather}}` expects the model in a
`staging > openweather` folder.

## Required tables

| Model | Raw tables |
|---|---|
| daily weather | `daily_aggregation` |
| daily forecast | `weather_forecast`, plus `daily_aggregation` for each location's UTC offset |

## Schema notes

- **Metric units.** The connector requests metric units from OpenWeather:
  °C, mm, m/s, hPa, %.
- **History builds over time.** The daily summary stream starts two years back
  and works forward within OpenWeather's daily call quota, so a first sync of many
  locations can take several days to fill.
- **Forecast steps are overwritten.** The 3-hourly forecast is keyed on location
  and time step, so each sync replaces the forecast for every future step. A past
  step keeps the last forecast made before it, which is what you would have
  planned with.
- **Local days.** The daily summary is already by local date. The forecast is in
  UTC and is assigned to local dates with the location's latest UTC offset from
  the daily stream; around a daylight saving change one step can land an hour off.
- **Thresholds are choices.** Wet day (1 mm), heavy rain (10 mm) and the
  temperature bands are set in `daily_weather`; change them to suit your climate
  and business.

## Reconciling

Nothing here has been run against a live warehouse. Compare a few days of
`daily_weather` with OpenWeather's history for the same coordinates, and check
that `steps_in_day` is 8 for the middle days of the forecast.

[OpenWeather One Call 3.0: daily aggregation](https://openweathermap.org/api/one-call-3#history_daily_aggregation) ·
[5 day / 3 hour forecast](https://openweathermap.org/forecast5)
