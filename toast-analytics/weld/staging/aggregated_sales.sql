-- staging.toast_analytics.aggregated_sales
-- Thin wrapper over raw `analytics_aggregated_sales`: Toast's own daily sales
-- metrics per restaurant, from the reporting (ERA) API. One row per restaurant x
-- business date.
--
-- Business dates arrive as text, as yyyymmdd or yyyy-mm-dd; both are parsed.
-- The connector requests these metrics without a group-by, so revenue center,
-- dining option, order source and business hour are empty.

SELECT
    CAST(restaurant_guid AS STRING)                     AS restaurant_id,
    CAST(restaurant_name AS STRING)                     AS restaurant_name,
    COALESCE(
        SAFE.PARSE_DATE('%Y%m%d', CAST(business_date AS STRING)),
        SAFE_CAST(LEFT(CAST(business_date AS STRING), 10) AS DATE)
    )                                                   AS business_date,
    CAST(orders_count AS INT64)                         AS orders,
    CAST(closed_orders_count AS INT64)                  AS closed_orders,
    CAST(void_orders_count AS INT64)                    AS voided_orders,
    CAST(discount_order_count AS INT64)                 AS discounted_orders,
    CAST(guest_count AS INT64)                          AS guests,
    CAST(gross_sales_amount AS FLOAT64)                 AS gross_sales,
    CAST(discount_amount AS FLOAT64)                    AS discounts,
    CAST(net_sales_amount AS FLOAT64)                   AS net_sales,
    CAST(refund_amount AS FLOAT64)                      AS refunds,
    CAST(void_orders_amount AS FLOAT64)                 AS voided_amount,
    CAST(hourly_job_total_hours AS FLOAT64)             AS hourly_labor_hours,
    CAST(hourly_job_total_pay AS FLOAT64)               AS hourly_labor_cost
FROM {{raw.toast_analytics.analytics_aggregated_sales}}
WHERE restaurant_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(restaurant_guid AS STRING), CAST(business_date AS STRING)
    ORDER BY _weld_synced DESC
) = 1
