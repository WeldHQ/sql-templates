-- staging.toast_analytics.menu_item
-- Thin wrapper over raw `analytics_menu_by_menu_item`: Toast's daily product mix
-- per menu item. One row per restaurant x business date x menu item.

SELECT
    CAST(restaurant_guid AS STRING)                     AS restaurant_id,
    CAST(restaurant_name AS STRING)                     AS restaurant_name,
    COALESCE(
        SAFE.PARSE_DATE('%Y%m%d', CAST(business_date AS STRING)),
        SAFE_CAST(LEFT(CAST(business_date AS STRING), 10) AS DATE)
    )                                                   AS business_date,
    CAST(menu_item_guid AS STRING)                      AS menu_item_id,
    CAST(menu_item_name AS STRING)                      AS menu_item_name,
    CAST(quantity_sold AS FLOAT64)                      AS quantity_sold,
    CAST(gross_sales_amount AS FLOAT64)                 AS gross_sales,
    CAST(discount_amount AS FLOAT64)                    AS discounts,
    CAST(net_sales_amount AS FLOAT64)                   AS net_sales,
    CAST(refund_amount AS FLOAT64)                      AS refunds,
    CAST(void_amount AS FLOAT64)                        AS voided_amount,
    CAST(waste_count AS FLOAT64)                        AS waste_quantity,
    CAST(waste_amount AS FLOAT64)                       AS waste_amount
FROM {{raw.toast_analytics.analytics_menu_by_menu_item}}
WHERE restaurant_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(restaurant_guid AS STRING), CAST(business_date AS STRING), CAST(menu_item_guid AS STRING)
    ORDER BY _weld_synced DESC
) = 1
