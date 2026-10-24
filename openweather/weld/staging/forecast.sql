-- staging.openweather.forecast
-- Thin wrapper over raw `weather_forecast`: OpenWeather's 5-day forecast in
-- 3-hour steps per configured location. One row per location x 3-hour step.
--
-- `dt` is the start of the step as Unix seconds (UTC). Each sync overwrites the
-- forecast for every step it returns, so a future step holds the latest forecast,
-- and a past step holds the last forecast made before it happened.
-- Metric units: °C, m/s, mm of rain in the 3 hours, `pop` is the probability of
-- precipitation from 0 to 1.

SELECT
    TIMESTAMP_SECONDS(CAST(dt AS INT64))        AS forecast_at,
    CAST(city AS STRING)                        AS city,
    UPPER(CAST(country AS STRING))              AS country,
    CAST(main_temp AS FLOAT64)                  AS temp_c,
    CAST(main_feels_like AS FLOAT64)            AS feels_like_c,
    CAST(main_temp_min AS FLOAT64)              AS temp_min_c,
    CAST(main_temp_max AS FLOAT64)              AS temp_max_c,
    CAST(main_humidity AS INT64)                AS humidity_pct,
    CAST(clouds_all AS INT64)                   AS cloud_cover_pct,
    CAST(wind_speed AS FLOAT64)                 AS wind_speed_ms,
    CAST(wind_gust AS FLOAT64)                  AS wind_gust_ms,
    CAST(pop AS FLOAT64)                        AS precipitation_probability,
    COALESCE(CAST(rain_3h AS FLOAT64), 0)       AS rain_mm,
    CAST(weather_main AS STRING)                AS weather_main,
    CAST(weather_description AS STRING)         AS weather_description
FROM {{raw.openweather.weather_forecast}}
WHERE dt IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(dt AS INT64), CAST(city AS STRING), CAST(country AS STRING)
    ORDER BY _weld_synced DESC
) = 1
