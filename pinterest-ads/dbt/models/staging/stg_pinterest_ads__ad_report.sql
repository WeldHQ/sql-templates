-- stg_pinterest_ads__ad_report
-- Thin wrapper over raw `ad_report`, Pinterest's daily analytics per ad. Casts,
-- renames, converts micros, de-duplicates. No other logic.
--
-- Grain: account_id x ad_id x date_day.
--
-- MONEY IS IN MICROS. Columns named *_IN_MICRO_DOLLAR hold millionths of the ad
-- account's currency, whatever that currency is; the "dollar" in the name is
-- historical. Staging divides by 1,000,000.
--
-- Attribution: the connector requests the report without attribution settings, so
-- Pinterest's API defaults apply: 30 days after a click, 30 days after an
-- engagement, 1 day after a view, with conversions dated on the day of the ad
-- action. Ads Manager uses the same defaults unless someone changed the view.
--
-- Delivery: impressions are paid impressions. The report does not carry paid-only
-- Pin clicks, so clicks are total Pin clicks (paid plus earned); paid outbound
-- clicks are kept as a separate column.

SELECT
    CAST(AD_ACCOUNT_ID AS STRING)                                      AS account_id,
    CAST(AD_ID AS STRING)                                              AS ad_id,
    SAFE_CAST(LEFT(CAST(`DATE` AS STRING), 10) AS DATE)                AS date_day,
    CAST(AD_GROUP_ID AS STRING)                                        AS ad_group_id,
    CAST(CAMPAIGN_ID AS STRING)                                        AS campaign_id,
    CAST(CAMPAIGN_NAME AS STRING)                                      AS report_campaign_name,
    CAST(PIN_ID AS STRING)                                             AS pin_id,
    COALESCE(CAST(SPEND_IN_MICRO_DOLLAR AS FLOAT64), 0) / 1000000      AS spend,
    CAST(COALESCE(IMPRESSION_1, CAST(PAID_IMPRESSION AS INT64), 0) AS INT64) AS impressions,
    COALESCE(CAST(IMPRESSION_2 AS INT64), 0)                           AS earned_impressions,
    CAST(COALESCE(TOTAL_CLICKTHROUGH, 0) AS INT64)                     AS clicks,
    CAST(COALESCE(OUTBOUND_CLICK_1, 0) AS INT64)                       AS paid_outbound_clicks,
    COALESCE(CAST(TOTAL_ENGAGEMENT AS FLOAT64), 0)                     AS engagements,
    COALESCE(CAST(TOTAL_CONVERSIONS AS FLOAT64), 0)                    AS conversions,
    CAST(TOTAL_CHECKOUT_VALUE_IN_MICRO_DOLLAR AS FLOAT64) / 1000000    AS checkout_value,
    CAST(TOTAL_CLICK_CHECKOUT_VALUE_IN_MICRO_DOLLAR AS FLOAT64) / 1000000      AS checkout_value_click,
    CAST(TOTAL_ENGAGEMENT_CHECKOUT_VALUE_IN_MICRO_DOLLAR AS FLOAT64) / 1000000 AS checkout_value_engagement,
    CAST(TOTAL_VIEW_CHECKOUT_VALUE_IN_MICRO_DOLLAR AS FLOAT64) / 1000000       AS checkout_value_view,
    CAST(TOTAL_WEB_CHECKOUT_VALUE_IN_MICRO_DOLLAR AS FLOAT64) / 1000000        AS web_checkout_value,
    COALESCE(CAST(TOTAL_SIGNUP AS FLOAT64), 0)                         AS signups
FROM {{ source('pinterest_ads', 'ad_report') }}
WHERE `DATE` IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY AD_ACCOUNT_ID, AD_ID, `DATE` ORDER BY _weld_synced DESC) = 1
