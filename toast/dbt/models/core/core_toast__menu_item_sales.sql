-- core_toast__menu_item_sales
-- Toast's Product Mix: quantity, gross and net sales and voids per menu item.
-- Grain: business date x restaurant x menu item x sales category.
--
-- Uses the same rules as core.toast.sales_summary (voided and deleted orders and
-- checks out, deferred selections out), so net_sales summed over items equals
-- net_sales in the sales summary for the same day and restaurant. Voided
-- selections are not in the sales columns; they are counted in voided_quantity
-- and voided_amount.
--
-- item_name is the name printed on the check. An item renamed in the menu shows
-- under its old name on old orders; group by menu_item_id to keep them together.

WITH valid_checks AS (
    SELECT c.check_id, o.business_date, o.restaurant_id
    FROM {{ ref('stg_toast__check') }} c
    JOIN {{ ref('stg_toast__order') }} o USING (order_id)
    WHERE NOT o.is_voided AND NOT o.is_deleted
      AND NOT c.is_voided AND NOT c.is_deleted
)

SELECT
    vc.business_date,
    vc.restaurant_id,
    s.menu_item_id,
    ANY_VALUE(s.item_name)                                         AS item_name,
    s.sales_category_id,
    ANY_VALUE(sc.sales_category_name)                              AS sales_category_name,
    SUM(IF(NOT s.is_voided, s.quantity, 0))                        AS quantity_sold,
    ROUND(SUM(IF(NOT s.is_voided, s.pre_discount_price, 0)), 2)    AS gross_sales,
    ROUND(SUM(IF(NOT s.is_voided, s.pre_discount_price - s.price, 0)), 2) AS discounts,
    ROUND(SUM(IF(NOT s.is_voided, s.price, 0)), 2)                 AS net_sales,
    ROUND(SUM(IF(NOT s.is_voided, s.refund_amount, 0)), 2)         AS refunds,
    SUM(IF(s.is_voided, s.quantity, 0))                            AS voided_quantity,
    ROUND(SUM(IF(s.is_voided, s.pre_discount_price, 0)), 2)        AS voided_amount,
    COUNT(DISTINCT IF(NOT s.is_voided, s.check_id, NULL))          AS checks_with_item
FROM {{ ref('stg_toast__selection') }} s
JOIN valid_checks vc USING (check_id)
LEFT JOIN {{ ref('stg_toast__sales_category') }} sc
       ON sc.sales_category_id = s.sales_category_id AND sc.restaurant_id = vc.restaurant_id
WHERE NOT s.is_deferred
GROUP BY vc.business_date, vc.restaurant_id, s.menu_item_id, s.sales_category_id
