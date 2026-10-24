-- core.applovin.ad_performance_daily
-- Daily delivery, installs and day-7 cohort revenue per creative set, the
-- AppLovin advertiser report by campaign and creative set.
--
-- Grain: date_day x campaign_id x creative set (ad_id). Days are UTC.
-- Currency: USD (see the README).
-- Depends on: staging.applovin.advertiser_report
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the other paid
-- ads templates in this repo, so they can be stacked with UNION ALL.
--
-- AppLovin's report has no stable ad id, so the creative set is the lowest level:
-- ad_id = creative_set_id, ad_name = the creative set name. The report has no
-- account column either: account_id and account_name are NULL, one Weld
-- connection being one AppLovin account.
-- conversions = installs. conversion_value = total revenue (in-app purchases plus
-- ad revenue) from users who installed that day, within 7 days. It is NULL for
-- the last seven days, until the window has elapsed.

WITH daily AS (
    -- The report splits each creative set by country, platform, device, placement,
    -- ad type and more; sum them back up to one row per creative set.
    SELECT
        date_day,
        campaign_id,
        creative_set_id,
        MAX(campaign_name)        AS campaign_name,
        MAX(campaign_type)        AS campaign_type,
        MAX(app_package_name)     AS app_package_name,
        MAX(creative_set_name)    AS creative_set_name,
        SUM(spend)                AS spend,
        SUM(impressions)          AS impressions,
        SUM(clicks)               AS clicks,
        SUM(installs)             AS installs,
        SUM(sales)                AS sales,
        SUM(total_revenue_d0)     AS total_revenue_d0,
        SUM(total_revenue_d7)     AS total_revenue_d7
    FROM {{staging.applovin.advertiser_report}}
    GROUP BY 1, 2, 3
)

SELECT
    date_day,
    CAST(NULL AS STRING)  AS account_id,
    CAST(NULL AS STRING)  AS account_name,
    campaign_id,
    campaign_name,
    creative_set_id       AS ad_id,
    creative_set_name     AS ad_name,
    spend,
    impressions,
    clicks,
    installs              AS conversions,
    total_revenue_d7      AS conversion_value,

    'applovin'            AS source,
    'USD'                 AS currency,
    campaign_type,
    app_package_name,
    sales,
    total_revenue_d0
FROM daily
