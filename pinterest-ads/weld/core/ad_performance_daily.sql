-- core.pinterest_ads.ad_performance_daily
-- Daily delivery and results per ad (promoted Pin), the Ads Manager "Ads" tab by day.
--
-- Grain: date_day x account_id x ad_id. Currency: the ad account's.
-- Depends on: staging.pinterest_ads.ad_report, .ad, .ad_group, .campaign, .ad_account
--
-- An ad account holds campaigns, campaigns hold ad groups, ad groups hold ads.
--
-- Conversion definition, under Pinterest's default attribution (30 day click,
-- 30 day engagement, 1 day view, dated on the ad action):
--   conversions      = TOTAL_CONVERSIONS, every conversion event type Pinterest
--                      counts (checkouts, sign-ups, leads, add to cart, page visits,
--                      custom), across web, app and offline.
--   conversion_value = checkout value across click, engagement and view
--                      attribution. Only checkouts carry value in this report.
-- So cost_per_conversion is spend per any conversion event, and roas is checkout
-- value per unit of spend, the same as Ads Manager's "Total ROAS (Checkout)". The
-- click, engagement and view split of checkout value is kept, so a click-only
-- value can be rebuilt for cross-channel comparisons.
--
-- impressions are paid impressions; clicks are total Pin clicks (the report does
-- not carry paid-only Pin clicks). See staging.pinterest_ads.ad_report.

WITH perf AS (
    SELECT
        r.date_day,
        r.account_id,
        acc.account_name,
        acc.currency,
        r.campaign_id,
        COALESCE(c.campaign_name, r.report_campaign_name) AS campaign_name,
        r.ad_group_id,
        g.ad_group_name,
        r.ad_id,
        a.ad_name,
        r.spend,
        r.impressions,
        r.clicks,
        r.conversions,
        r.checkout_value                 AS conversion_value,
        c.objective_type                 AS campaign_objective,
        a.ad_status,
        a.creative_type,
        r.pin_id,
        r.earned_impressions,
        r.paid_outbound_clicks,
        r.engagements,
        r.signups,
        r.checkout_value_click,
        r.checkout_value_engagement,
        r.checkout_value_view,
        r.web_checkout_value
    FROM {{staging.pinterest_ads.ad_report}} r
    -- Every join carries account_id. Staging keeps one row per id, so nothing can
    -- fan out. LEFT JOINs keep the spend of ads missing from the entity tables.
    LEFT JOIN {{staging.pinterest_ads.ad}} a
        ON a.account_id = r.account_id
       AND a.ad_id = r.ad_id
    LEFT JOIN {{staging.pinterest_ads.ad_group}} g
        ON g.account_id = r.account_id
       AND g.ad_group_id = r.ad_group_id
    LEFT JOIN {{staging.pinterest_ads.campaign}} c
        ON c.account_id = r.account_id
       AND c.campaign_id = r.campaign_id
    LEFT JOIN {{staging.pinterest_ads.ad_account}} acc
        ON acc.account_id = r.account_id
)

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    ad_group_id,
    ad_group_name,
    ad_id,
    ad_name,
    spend,
    impressions,
    clicks,
    conversions,
    conversion_value,
    SAFE_DIVIDE(clicks, impressions)        AS ctr,
    SAFE_DIVIDE(spend, clicks)              AS cpc,
    SAFE_DIVIDE(spend, impressions) * 1000  AS cpm,
    SAFE_DIVIDE(spend, conversions)         AS cost_per_conversion,
    SAFE_DIVIDE(conversion_value, spend)    AS roas,

    'pinterest_ads'                         AS source,
    campaign_objective,
    ad_status,
    creative_type,
    pin_id,
    earned_impressions,
    paid_outbound_clicks,
    engagements,
    signups,
    checkout_value_click,
    checkout_value_engagement,
    checkout_value_view,
    web_checkout_value
FROM perf
