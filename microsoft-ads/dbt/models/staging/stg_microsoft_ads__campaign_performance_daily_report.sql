-- stg_microsoft_ads__campaign_performance_daily_report
-- Thin wrapper over raw `campaign_performance_daily_report`,
-- Microsoft Advertising's daily campaign performance report. Casts,
-- renames, de-duplicates. No other logic.
--
-- Grain: the report's own key, which splits each campaign and day by device,
-- network, match type, ad distribution, top vs other placement and budget.
-- Core collapses those splits.
--
-- spend and revenue are in the account's currency (currency_code), not in
-- micros. conversions counts conversion goals set to "Include in conversions";
-- all_conversions counts every goal. Both are dated on the day of the ad click.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(date AS DATE)                              AS date_day,
        CAST(account_id AS STRING)                      AS account_id,
        CAST(campaign_id AS STRING)                     AS campaign_id,
        UPPER(CAST(currency_code AS STRING))            AS currency,
        COALESCE(CAST(spend AS FLOAT64), 0)             AS spend,
        COALESCE(CAST(impressions AS INT64), 0)         AS impressions,
        COALESCE(CAST(clicks AS INT64), 0)              AS clicks,
        COALESCE(CAST(conversions AS FLOAT64), 0)       AS conversions,
        COALESCE(CAST(revenue AS FLOAT64), 0)           AS revenue,
        COALESCE(CAST(all_conversions AS FLOAT64), 0)   AS all_conversions,
        COALESCE(CAST(all_revenue AS FLOAT64), 0)       AS all_revenue,
        COALESCE(CAST(view_through_conversions AS INT64), 0) AS view_through_conversions,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, campaign_id, ad_distribution, bid_match_type, currency_code, date,
                         delivered_match_type, device_os, device_type, network,
                         top_vs_other, budget_name
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('microsoft_ads', 'campaign_performance_daily_report') }}
)
WHERE row_rank = 1
