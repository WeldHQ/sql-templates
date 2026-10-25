-- staging.pinterest_ads.ad_group
-- Thin wrapper over raw `ad_group`. Casts, renames, converts micros, keeps the
-- latest row per ad group.
-- Grain: one row per ad group.

SELECT
    CAST(id AS STRING)                             AS ad_group_id,
    CAST(ad_account_id AS STRING)                  AS account_id,
    CAST(campaign_id AS STRING)                    AS campaign_id,
    CAST(name AS STRING)                           AS ad_group_name,
    CAST(status AS STRING)                         AS ad_group_status,
    CAST(billable_event AS STRING)                 AS billable_event,
    CAST(bid_strategy_type AS STRING)              AS bid_strategy_type,
    CAST(budget_type AS STRING)                    AS budget_type,
    CAST(budget_in_micro_currency AS FLOAT64) / 1000000 AS budget,
    CAST(bid_in_micro_currency AS FLOAT64) / 1000000    AS bid
FROM {{raw.pinterest_ads.ad_group}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY ad_account_id, id ORDER BY _weld_synced DESC) = 1
