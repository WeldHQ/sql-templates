-- daily_weather and daily_forecast each have one row per location and date.
-- Returns zero rows when both hold.

SELECT 'daily_weather' AS model, date, city, country, COUNT(*) AS n
FROM {{ ref('core_openweather__daily_weather') }}
GROUP BY 2, 3, 4
HAVING COUNT(*) > 1

UNION ALL

SELECT 'daily_forecast', forecast_date, city, country, COUNT(*)
FROM {{ ref('core_openweather__daily_forecast') }}
GROUP BY 2, 3, 4
HAVING COUNT(*) > 1
