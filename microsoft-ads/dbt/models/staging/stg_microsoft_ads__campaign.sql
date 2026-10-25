-- stg_microsoft_ads__campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per campaign. The connector lands the campaign name in a column
-- called `campaign`, as in Microsoft's bulk file.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                AS campaign_id,
        CAST(account_id AS STRING)        AS account_id,
        CAST(campaign AS STRING)          AS campaign_name,
        CAST(campaign_type AS STRING)     AS campaign_type,
        CAST(status AS STRING)            AS campaign_status,
        CAST(bid_strategy_type AS STRING) AS bid_strategy_type,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('microsoft_ads', 'campaign') }}
)
WHERE row_rank = 1
