-- stg_reddit_ads__campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per campaign.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)               AS campaign_id,
        CAST(name AS STRING)             AS campaign_name,
        CAST(ad_account_id AS STRING)    AS account_id,
        CAST(objective AS STRING)        AS objective,
        CAST(effective_status AS STRING) AS effective_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('reddit_ads', 'campaign') }}
)
WHERE row_rank = 1
