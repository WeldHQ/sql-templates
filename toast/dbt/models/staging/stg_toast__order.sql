-- stg_toast__order
-- Thin wrapper over raw `order`. One row per order, latest version.
--
-- Toast stores the business date as a number like 20240115; it is turned into a
-- DATE here. The business date is the restaurant's trading day, so a 1am order
-- after a late service belongs to the previous day, exactly as in Toast's reports.
-- Orders created in test mode are dropped.

SELECT
    CAST(guid AS STRING)                                AS order_id,
    CAST(restaurant_guid AS STRING)                     AS restaurant_id,
    SAFE.PARSE_DATE('%Y%m%d', CAST(CAST(business_date AS INT64) AS STRING)) AS business_date,
    CAST(opened_date AS TIMESTAMP)                      AS opened_at,
    CAST(closed_date AS TIMESTAMP)                      AS closed_at,
    CAST(dining_option_guid AS STRING)                  AS dining_option_id,
    CAST(revenue_center_guid AS STRING)                 AS revenue_center_id,
    CAST(server_guid AS STRING)                         AS server_id,
    CAST(source AS STRING)                              AS order_source,
    CAST(number_of_guests AS INT64)                     AS guests,
    COALESCE(voided, FALSE)                             AS is_voided,
    COALESCE(deleted, FALSE)                            AS is_deleted,
    CAST(modified_date AS TIMESTAMP)                    AS modified_at
FROM {{ source('toast', 'order') }}
WHERE guid IS NOT NULL
  AND COALESCE(created_in_test_mode, FALSE) = FALSE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(modified_date AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
