-- core_openweather__daily_weather
-- Daily weather per location, shaped for joining to sales, covers or footfall on
-- date: temperatures, rain, wind, and a few plain-language flags.
-- Grain: date x location (city, country).
--
-- The flags use fixed thresholds you may want to tune for your climate:
--   is_wet_day      at least 1 mm of precipitation
--   is_heavy_rain   at least 10 mm
--   temp_band       on the daily maximum: below 5, 5-15, 15-25, 25 and above (°C)
-- temp_max_vs_7d_avg is the day's maximum against the average maximum of the
-- seven days before it at the same location: "warmer than last week" in degrees.

SELECT
    date,
    city,
    country,
    FORMAT_DATE('%A', date)                         AS weekday,
    temp_min_c,
    temp_max_c,
    temp_afternoon_c,
    temp_evening_c,
    precipitation_mm,
    precipitation_mm >= 1                           AS is_wet_day,
    precipitation_mm >= 10                          AS is_heavy_rain,
    CASE
        WHEN temp_max_c < 5  THEN 'below_5c'
        WHEN temp_max_c < 15 THEN '5_15c'
        WHEN temp_max_c < 25 THEN '15_25c'
        ELSE '25c_and_above'
    END                                             AS temp_band,
    humidity_afternoon_pct,
    cloud_cover_afternoon_pct,
    wind_max_speed_ms,
    ROUND(temp_max_c - AVG(temp_max_c) OVER (
        PARTITION BY city, country
        ORDER BY UNIX_DATE(date)
        RANGE BETWEEN 7 PRECEDING AND 1 PRECEDING
    ), 1)                                           AS temp_max_vs_7d_avg
FROM {{ ref('stg_openweather__daily_weather') }}
WHERE date IS NOT NULL
