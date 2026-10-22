-- A local day has at most eight 3-hour forecast steps. More means the UTC offset
-- was missing or wrong for a location, or duplicate steps survived staging.
-- Returns zero rows when it holds.

SELECT forecast_date, city, country, steps_in_day
FROM {{ ref('core_openweather__daily_forecast') }}
WHERE steps_in_day > 8
