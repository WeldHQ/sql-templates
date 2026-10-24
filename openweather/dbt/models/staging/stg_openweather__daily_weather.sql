-- stg_openweather__daily_weather
-- Thin wrapper over raw `daily_aggregation`: OpenWeather's daily summary (One Call
-- 3.0 day_summary) per configured location. One row per location x day.
--
-- Values are in metric units: temperatures in °C, precipitation in mm,
-- wind speed in m/s, pressure in hPa, humidity and cloud cover in %. `date` is the
-- local date at the location; `tz` is its UTC offset (for example +01:00).

SELECT
    SAFE_CAST(CAST(date AS STRING) AS DATE)     AS date,
    CAST(city AS STRING)                        AS city,
    UPPER(CAST(country AS STRING))              AS country,
    CAST(lat AS FLOAT64)                        AS lat,
    CAST(lon AS FLOAT64)                        AS lon,
    CAST(tz AS STRING)                          AS utc_offset,
    CAST(temperature_min AS FLOAT64)            AS temp_min_c,
    CAST(temperature_max AS FLOAT64)            AS temp_max_c,
    CAST(temperature_morning AS FLOAT64)        AS temp_morning_c,
    CAST(temperature_afternoon AS FLOAT64)      AS temp_afternoon_c,
    CAST(temperature_evening AS FLOAT64)        AS temp_evening_c,
    CAST(temperature_night AS FLOAT64)          AS temp_night_c,
    CAST(precipitation_total AS FLOAT64)        AS precipitation_mm,
    CAST(humidity_afternoon AS FLOAT64)         AS humidity_afternoon_pct,
    CAST(cloud_cover_afternoon AS FLOAT64)      AS cloud_cover_afternoon_pct,
    CAST(pressure_afternoon AS FLOAT64)         AS pressure_afternoon_hpa,
    CAST(wind_max_speed AS FLOAT64)             AS wind_max_speed_ms,
    CAST(wind_max_direction AS FLOAT64)         AS wind_max_direction_deg
FROM {{ source('openweather', 'daily_aggregation') }}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(date AS STRING), CAST(city AS STRING), CAST(country AS STRING)
    ORDER BY _weld_synced DESC
) = 1
