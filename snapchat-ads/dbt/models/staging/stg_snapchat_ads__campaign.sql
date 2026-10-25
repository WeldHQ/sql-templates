-- stg_snapchat_ads__campaign
-- Thin wrapper over raw `campaign`. Casts, renames, converts budgets from micros,
-- keeps the latest row per campaign.
-- Grain: one row per ad account and campaign.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(ad_account_id AS STRING)               AS account_id,
        CAST(id AS STRING)                          AS campaign_id,
        CAST(name AS STRING)                        AS campaign_name,
        CAST(objective AS STRING)                   AS campaign_objective,
        CAST(status AS STRING)                      AS campaign_status,
        CAST(delivery_status AS STRING)             AS campaign_delivery_status,
        CAST(daily_budget_micro AS NUMERIC) / 1000000 AS campaign_daily_budget,
        COALESCE(CAST(deleted AS BOOL), FALSE)      AS is_deleted,
        ROW_NUMBER() OVER (PARTITION BY ad_account_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('snapchat_ads', 'campaign') }}
)
WHERE row_rank = 1
