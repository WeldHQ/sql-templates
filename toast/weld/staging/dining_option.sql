-- staging.toast.dining_option
-- Thin wrapper over raw `dining_option`: the names behind the dining_option_id on orders and
-- selections. One row per dining_option per restaurant.

SELECT
    CAST(guid AS STRING)            AS dining_option_id,
    CAST(restaurant_guid AS STRING) AS restaurant_id,
    CAST(name AS STRING)            AS dining_option_name
FROM {{raw.toast.dining_option}}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING), CAST(restaurant_guid AS STRING)
    ORDER BY _weld_synced DESC
) = 1
