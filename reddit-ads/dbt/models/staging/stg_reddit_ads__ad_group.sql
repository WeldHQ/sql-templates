-- stg_reddit_ads__ad_group
-- Thin wrapper over raw `ad_group`. Casts, renames, keeps the latest row per ad group.
-- Grain: one row per ad group.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                AS ad_group_id,
        CAST(name AS STRING)              AS ad_group_name,
        CAST(campaign_id AS STRING)       AS campaign_id,
        CAST(ad_account_id AS STRING)     AS account_id,
        CAST(optimization_goal AS STRING) AS optimization_goal,
        CAST(bid_strategy AS STRING)      AS bid_strategy,
        CAST(effective_status AS STRING)  AS effective_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('reddit_ads', 'ad_group') }}
)
WHERE row_rank = 1
