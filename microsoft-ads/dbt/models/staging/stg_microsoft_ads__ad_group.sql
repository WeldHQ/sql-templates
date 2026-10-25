-- stg_microsoft_ads__ad_group
-- Thin wrapper over raw `ad_group`. Casts, renames, keeps the latest row per ad group.
-- Grain: one row per ad group. In Microsoft's bulk file layout, parent_id is the
-- campaign ID and `ad_group` holds the ad group's name.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)            AS ad_group_id,
        CAST(parent_id AS STRING)     AS campaign_id,
        CAST(account_id AS STRING)    AS account_id,
        CAST(ad_group AS STRING)      AS ad_group_name,
        CAST(ad_group_type AS STRING) AS ad_group_type,
        CAST(status AS STRING)        AS ad_group_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('microsoft_ads', 'ad_group') }}
)
WHERE row_rank = 1
