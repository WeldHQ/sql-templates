-- Spend, impressions, clicks and conversions can never be negative. A negative
-- value usually means a column was mapped or converted wrongly in staging.

SELECT *
FROM {{ ref('core_pinterest_ads__ad_performance_daily') }}
WHERE spend < 0 OR impressions < 0 OR clicks < 0 OR conversions < 0
