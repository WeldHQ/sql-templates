-- Spend, impressions, clicks and conversions can never be negative. A negative
-- value usually means a field was mapped to the wrong report column.

SELECT *
FROM {{ ref('core_snapchat_ads__ad_performance_daily') }}
WHERE spend < 0 OR impressions < 0 OR clicks < 0 OR conversions < 0
