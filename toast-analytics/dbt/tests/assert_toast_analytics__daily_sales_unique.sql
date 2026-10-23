-- daily_sales is unique on business date x restaurant. Toast's reporting API is
-- re-read for recent days on every sync; a duplicate means a business date was
-- stored in two text formats and parsed to the same day. Returns zero rows when
-- it holds.

SELECT business_date, restaurant_id, COUNT(*) AS n
FROM {{ ref('core_toast_analytics__daily_sales') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
