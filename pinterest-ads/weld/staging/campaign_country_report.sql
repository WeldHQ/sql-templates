-- staging.pinterest_ads.campaign_country_report
-- Thin wrapper over raw `campaign_country_report`, Pinterest's daily campaign
-- analytics broken down by the viewer's country. Casts, renames, converts micros,
-- de-duplicates.
--
-- Grain: account_id x campaign_id x country_code x date_day.
--
-- Same units and attribution as staging.pinterest_ads.ad_report: micros divided by
-- 1,000,000, API default windows (30 day click, 30 day engagement, 1 day view).
-- The connector requests only the country breakdown for this stream, so every row
-- is a country row.

SELECT
    CAST(AD_ACCOUNT_ID AS STRING)                                      AS account_id,
    CAST(CAMPAIGN_ID AS STRING)                                        AS campaign_id,
    CAST(TARGETING_VALUE AS STRING)                                    AS country_code,
    SAFE_CAST(LEFT(CAST(`DATE` AS STRING), 10) AS DATE)                AS date_day,
    CAST(CAMPAIGN_NAME AS STRING)                                      AS report_campaign_name,
    COALESCE(CAST(SPEND_IN_MICRO_DOLLAR AS FLOAT64), 0) / 1000000      AS spend,
    CAST(COALESCE(IMPRESSION_1, CAST(PAID_IMPRESSION AS INT64), 0) AS INT64) AS impressions,
    CAST(COALESCE(TOTAL_CLICKTHROUGH, 0) AS INT64)                     AS clicks,
    COALESCE(CAST(TOTAL_CONVERSIONS AS FLOAT64), 0)                    AS conversions,
    CAST(TOTAL_CHECKOUT_VALUE_IN_MICRO_DOLLAR AS FLOAT64) / 1000000    AS checkout_value
FROM {{raw.pinterest_ads.campaign_country_report}}
WHERE `DATE` IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY AD_ACCOUNT_ID, CAMPAIGN_ID, TARGETING_VALUE, `DATE`
    ORDER BY _weld_synced DESC
) = 1
