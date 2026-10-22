-- stg_toast__revenue_center
-- Thin wrapper over raw `revenue_center`: the names behind the revenue_center_id on orders and
-- selections. One row per revenue_center per restaurant.

SELECT
    CAST(guid AS STRING)            AS revenue_center_id,
    CAST(restaurant_guid AS STRING) AS restaurant_id,
    CAST(name AS STRING)            AS revenue_center_name
FROM {{ source('toast', 'revenue_center') }}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING), CAST(restaurant_guid AS STRING)
    ORDER BY _weld_synced DESC
) = 1
