-- stg_amazon_attribution__profile
-- Thin wrapper over raw `profile`, the Amazon Ads profiles selected on the connection.
-- Casts, renames, keeps the latest row per profile.
-- Grain: one row per profile.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(profile_id AS STRING)                         AS profile_id,
        CAST(account_info_name AS STRING)                  AS profile_name,
        CAST(account_info_type AS STRING)                  AS profile_type,
        CAST(account_info_marketplace_string_id AS STRING) AS marketplace_id,
        CAST(country_code AS STRING)                       AS country_code,
        UPPER(CAST(currency_code AS STRING))               AS currency,
        CAST(timezone AS STRING)                           AS time_zone,
        ROW_NUMBER() OVER (PARTITION BY profile_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('amazon_attribution', 'profile') }}
)
WHERE row_rank = 1
