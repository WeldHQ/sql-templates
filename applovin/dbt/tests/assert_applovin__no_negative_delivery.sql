-- Spend, impressions, clicks and installs can never be negative. A negative value
-- usually means a field was mapped to the wrong report column.

SELECT *
FROM {{ ref('core_applovin__campaign_performance_daily') }}
WHERE spend < 0 OR impressions < 0 OR clicks < 0 OR installs < 0
