-- staging.toast.restaurant
-- Thin wrapper over raw `restaurant`. One row per restaurant location.

SELECT
    CAST(restaurant_guid AS STRING)   AS restaurant_id,
    CAST(restaurant_name AS STRING)   AS restaurant_name,
    CAST(location_name AS STRING)     AS location_name
FROM {{raw.toast.restaurant}}
WHERE restaurant_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(restaurant_guid AS STRING) ORDER BY _weld_synced DESC) = 1
