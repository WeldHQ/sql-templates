-- staging.facebook_ads.ad_set
-- Thin wrapper over raw `ad_set`. Casts, renames, keeps the latest row per ad set.
-- Grain: one row per ad set.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                                       AS ad_set_id,
        CAST(campaign_id AS STRING)                              AS campaign_id,
        REGEXP_REPLACE(CAST(account_id AS STRING), r'^act_', '') AS account_id,
        CAST(name AS STRING)                                     AS ad_set_name,
        CAST(optimization_goal AS STRING)                        AS optimization_goal,
        CAST(billing_event AS STRING)                            AS billing_event,
        CAST(bid_strategy AS STRING)                             AS bid_strategy,
        CAST(effective_status AS STRING)                         AS effective_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.facebook_ads.ad_set}}
)
WHERE row_rank = 1
