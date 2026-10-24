-- staging.toast_analytics.labor
-- Thin wrapper over raw `analytics_labor`: Toast's daily labor totals per
-- restaurant, with the net sales Toast uses for its labor percentage. One row per
-- restaurant x business date.

SELECT
    CAST(restaurant_guid AS STRING)                     AS restaurant_id,
    COALESCE(
        SAFE.PARSE_DATE('%Y%m%d', CAST(business_date AS STRING)),
        SAFE_CAST(LEFT(CAST(business_date AS STRING), 10) AS DATE)
    )                                                   AS business_date,
    CAST(total_hours AS FLOAT64)                        AS total_hours,
    CAST(total_cost AS FLOAT64)                         AS total_cost,
    CAST(net_sales_amount AS FLOAT64)                   AS net_sales
FROM {{raw.toast_analytics.analytics_labor}}
WHERE restaurant_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(restaurant_guid AS STRING), CAST(business_date AS STRING)
    ORDER BY _weld_synced DESC
) = 1
