-- staging.microsoft_ads.ad_group_performance_daily_report
-- Thin wrapper over raw `ad_group_performance_daily_report`,
-- Microsoft Advertising's daily ad group performance report. Casts,
-- renames, de-duplicates. No other logic.
--
-- Grain: the report's own key, which splits each ad group and day by device,
-- network, match type, ad distribution, top vs other placement and language.
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
        CAST(ad_group_id AS STRING)                     AS ad_group_id,
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
            PARTITION BY account_id, ad_distribution, ad_group_id, bid_match_type, campaign_id,
                         currency_code, date, delivered_match_type, device_os, device_type,
                         language, network, top_vs_other
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.microsoft_ads.ad_group_performance_daily_report}}
)
WHERE row_rank = 1
