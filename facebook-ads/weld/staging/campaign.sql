-- staging.facebook_ads.campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per campaign.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                                       AS campaign_id,
        REGEXP_REPLACE(CAST(account_id AS STRING), r'^act_', '') AS account_id,
        CAST(name AS STRING)                                     AS campaign_name,
        CAST(objective AS STRING)                                AS objective,
        CAST(buying_type AS STRING)                              AS buying_type,
        CAST(effective_status AS STRING)                         AS effective_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.facebook_ads.campaign}}
)
WHERE row_rank = 1
