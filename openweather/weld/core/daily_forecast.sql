-- core.openweather.daily_forecast
-- The 3-hourly forecast rolled up to local days per location: the next five days
-- of weather in the same shape as core.openweather.daily_weather, for staffing
-- and ordering decisions.
-- Grain: local date x location (city, country).
--
-- Steps are assigned to local dates using the location's UTC offset from the
-- daily weather stream; locations without daily weather fall back to UTC. The
-- first and last day are partial (the forecast starts now and ends five days out);
-- steps_in_day says how many 3-hour steps a day has, 8 being a full day.
-- Past dates keep the last forecast made before them, which lets you compare
-- forecast with actual using core.openweather.daily_weather.

WITH offsets AS (
    SELECT city, country, utc_offset
    FROM {{staging.openweather.daily_weather}}
    WHERE utc_offset IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY city, country ORDER BY date DESC) = 1
),

steps AS (
    SELECT
        f.*,
        DATE(f.forecast_at, COALESCE(o.utc_offset, '+00:00')) AS forecast_date
    FROM {{staging.openweather.forecast}} f
    LEFT JOIN offsets o USING (city, country)
)

SELECT
    forecast_date,
    city,
    country,
    COUNT(*)                                        AS steps_in_day,
    MIN(temp_min_c)                                 AS temp_min_c,
    MAX(temp_max_c)                                 AS temp_max_c,
    ROUND(AVG(feels_like_c), 1)                     AS avg_feels_like_c,
    ROUND(SUM(rain_mm), 1)                          AS rain_mm,
    MAX(precipitation_probability)                  AS max_precipitation_probability,
    MAX(wind_speed_ms)                              AS max_wind_speed_ms,
    APPROX_TOP_COUNT(weather_main, 1)[OFFSET(0)].value AS most_common_weather,
    forecast_date >= CURRENT_DATE()                 AS is_upcoming
FROM steps
GROUP BY 1, 2, 3
