-- staging.linkedin_ads.campaign
-- Thin wrapper over raw `campaign`. Casts, renames, keeps the latest row per campaign.
-- Grain: one row per campaign.
--
-- The connector skips LinkedIn test campaigns, so creatives that belong to one have
-- no match here.

SELECT
    CAST(id AS STRING)                         AS campaign_id,
    CAST(account_id AS STRING)                 AS account_id,
    CAST(campaign_group_id AS STRING)          AS campaign_group_id,
    CAST(name AS STRING)                       AS campaign_name,
    CAST(status AS STRING)                     AS campaign_status,
    CAST(objective_type AS STRING)             AS objective_type,
    CAST(type AS STRING)                       AS campaign_type,
    CAST(format AS STRING)                     AS ad_format,
    CAST(cost_type AS STRING)                  AS cost_type,
    CAST(optimization_target_type AS STRING)   AS optimization_target_type,
    CAST(daily_budget_amount AS FLOAT64)       AS daily_budget_amount,
    UPPER(CAST(daily_budget_currency_code AS STRING)) AS daily_budget_currency
FROM {{raw.linkedin_ads.campaign}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id, id ORDER BY _weld_synced DESC) = 1
