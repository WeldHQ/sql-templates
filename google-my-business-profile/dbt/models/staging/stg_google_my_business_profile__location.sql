-- stg_google_my_business_profile__location
-- Thin wrapper over raw `account_location`. Casts, renames, keeps the latest row
-- per location. No other logic.
-- Grain: one row per location.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                                       AS location_id,
        CAST(account_id AS STRING)                               AS account_id,
        CAST(title AS STRING)                                    AS location_name,
        CAST(store_code AS STRING)                               AS store_code,
        CAST(storefront_address_locality AS STRING)              AS locality,
        CAST(storefront_address_region_code AS STRING)           AS region_code,
        CAST(categories_primary_category_display_name AS STRING) AS primary_category,
        CAST(open_info_status AS STRING)                         AS open_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('google_my_business_profile', 'account_location') }}
)
WHERE row_rank = 1
