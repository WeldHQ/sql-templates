-- staging.toast.sales_category
-- Thin wrapper over raw `sales_category`: the names behind the sales_category_id on orders and
-- selections. One row per sales_category per restaurant.

SELECT
    CAST(guid AS STRING)            AS sales_category_id,
    CAST(restaurant_guid AS STRING) AS restaurant_id,
    CAST(name AS STRING)            AS sales_category_name
FROM {{raw.toast.sales_category}}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING), CAST(restaurant_guid AS STRING)
    ORDER BY _weld_synced DESC
) = 1
