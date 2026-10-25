-- staging.tiktok_ads.ad_group
-- Thin wrapper over raw `ad_group`. Ad groups hold targeting, bidding, budget and
-- the optimisation goal, which decides what the report's "conversion" counts.
-- Casts, renames, keeps the latest row per ad group.
-- Grain: one row per advertiser and ad group.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)    AS account_id,
        CAST(id AS STRING)               AS ad_group_id,
        CAST(adgroup_name AS STRING)     AS ad_group_name,
        CAST(campaign_id AS STRING)      AS campaign_id,
        CAST(optimize_goal AS STRING)    AS optimization_goal,
        CAST(external_action AS STRING)  AS optimization_event,
        CAST(billing_event AS STRING)    AS billing_event,
        CAST(bid_type AS STRING)         AS bid_type,
        CAST(placement_type AS STRING)   AS placement_type,
        CAST(budget_mode AS STRING)      AS budget_mode,
        CAST(budget AS FLOAT64)          AS budget,
        CAST(opt_status AS STRING)       AS ad_group_status,
        ROW_NUMBER() OVER (PARTITION BY advertiser_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.tiktok_ads.ad_group}}
)
WHERE row_rank = 1
