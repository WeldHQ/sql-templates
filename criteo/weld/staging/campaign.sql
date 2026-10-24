-- staging.criteo.campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per campaign.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                       AS campaign_id,
        CAST(attributes_name AS STRING)          AS campaign_name,
        CAST(attributes_advertiser_id AS STRING) AS account_id,
        CAST(attributes_goal AS STRING)          AS campaign_goal,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.criteo.campaign}}
)
WHERE row_rank = 1
