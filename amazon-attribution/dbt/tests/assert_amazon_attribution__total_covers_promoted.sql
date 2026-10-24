-- Total metrics are promoted products plus brand halo, so they can never be smaller
-- than the promoted ones, and nothing here can be negative. A failure usually means
-- two report fields were mapped to the wrong columns.

SELECT *
FROM {{ ref('core_amazon_attribution__campaign_performance_daily') }}
WHERE click_throughs < 0
   OR purchases < 0
   OR sales < 0
   OR total_purchases < purchases
   OR total_sales < sales
