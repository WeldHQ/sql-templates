-- core_toast_analytics__menu_item_performance
-- Toast's Product Mix per menu item and day, with waste and each item's share of
-- the restaurant's item sales.
-- Grain: business date x restaurant x menu item.
--
-- share_of_item_net_sales is the item's net sales over the sum of all items' net
-- sales for that restaurant and day. It is a share of item sales, not of the
-- restaurant's total net sales, which can differ by service charges and other
-- non-item revenue.

SELECT
    business_date,
    restaurant_id,
    restaurant_name,
    menu_item_id,
    menu_item_name,
    quantity_sold,
    gross_sales,
    discounts,
    net_sales,
    refunds,
    voided_amount,
    waste_quantity,
    waste_amount,
    SAFE_DIVIDE(net_sales, quantity_sold)          AS avg_net_price,
    SAFE_DIVIDE(net_sales, SUM(net_sales) OVER (PARTITION BY restaurant_id, business_date)) AS share_of_item_net_sales
FROM {{ ref('stg_toast_analytics__menu_item') }}
