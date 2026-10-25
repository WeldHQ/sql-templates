-- staging.google_ads.ad_group
-- Thin wrapper over raw `ad_group`. Casts, renames, keeps the latest row per ad group.
-- Grain: one row per account x ad group.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(account_id AS STRING)       AS account_id,
        CAST(campaign_id AS STRING)      AS campaign_id,
        CAST(id AS STRING)               AS ad_group_id,
        CAST(name AS STRING)             AS ad_group_name,
        CAST(type AS STRING)             AS ad_group_type,
        CAST(status AS STRING)           AS ad_group_status,
        CAST(final_url_suffix AS STRING) AS final_url_suffix,
        ROW_NUMBER() OVER (PARTITION BY account_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.google_ads.ad_group}}
)
WHERE row_rank = 1
