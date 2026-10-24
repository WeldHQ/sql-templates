-- Item shares of net sales add up to 1 per restaurant and day (where there were
-- item sales). Returns zero rows when it holds.

SELECT restaurant_id, business_date, SUM(share_of_item_net_sales) AS total_share
FROM {{ ref('core_toast_analytics__menu_item_performance') }}
GROUP BY 1, 2
HAVING SUM(share_of_item_net_sales) IS NOT NULL
   AND ABS(SUM(share_of_item_net_sales) - 1) > 0.0001
