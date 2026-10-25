-- stg_tiktok_ads__campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per advertiser and campaign.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)    AS account_id,
        CAST(id AS STRING)               AS campaign_id,
        CAST(campaign_name AS STRING)    AS campaign_name,
        CAST(objective_type AS STRING)   AS campaign_objective,
        CAST(budget_mode AS STRING)      AS campaign_budget_mode,
        CAST(budget AS FLOAT64)          AS campaign_budget,
        CAST(opt_status AS STRING)       AS campaign_status,
        ROW_NUMBER() OVER (PARTITION BY advertiser_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('tiktok_ads', 'campaign') }}
)
WHERE row_rank = 1
