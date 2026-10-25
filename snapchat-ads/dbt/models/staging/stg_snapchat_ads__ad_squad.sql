-- stg_snapchat_ads__ad_squad
-- Thin wrapper over raw `ad_squad`. Ad squads are Snapchat's ad sets: they hold
-- targeting, bidding, budget and the optimisation goal. Casts, renames, converts
-- micros, keeps the latest row per ad squad.
-- Grain: one row per ad account and ad squad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(ad_account_id AS STRING)                 AS account_id,
        CAST(id AS STRING)                            AS ad_squad_id,
        CAST(name AS STRING)                          AS ad_squad_name,
        CAST(campaign_id AS STRING)                   AS campaign_id,
        CAST(status AS STRING)                        AS ad_squad_status,
        CAST(optimization_goal AS STRING)             AS optimization_goal,
        CAST(bid_strategy AS STRING)                  AS bid_strategy,
        CAST(billing_event AS STRING)                 AS billing_event,
        CAST(placement AS STRING)                     AS placement,
        CAST(daily_budget_micro AS NUMERIC) / 1000000 AS daily_budget,
        CAST(bid_micro AS NUMERIC) / 1000000          AS bid_amount,
        COALESCE(CAST(deleted AS BOOL), FALSE)        AS is_deleted,
        ROW_NUMBER() OVER (PARTITION BY ad_account_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('snapchat_ads', 'ad_squad') }}
)
WHERE row_rank = 1
