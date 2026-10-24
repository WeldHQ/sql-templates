-- Discounts (gross minus net) should not be negative. A negative value means
-- pre_discount_price excludes something that price includes, for example modifier
-- prices under some menu set-ups, and gross_sales is understated.
-- Returns zero rows when it holds.

SELECT business_date, restaurant_id, revenue_center_id, dining_option_id, gross_sales, net_sales, discounts
FROM {{ ref('core_toast__sales_summary') }}
WHERE discounts < -0.01
