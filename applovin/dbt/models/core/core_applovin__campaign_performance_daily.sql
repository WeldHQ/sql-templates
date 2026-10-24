-- core_applovin__campaign_performance_daily
-- Daily campaign performance with the rates AppLovin shows: CTR, CPC, CPM, cost
-- per install (CPI), install rate and day-0 and day-7 ROAS.
--
-- Grain: date_day x campaign_id. Days are UTC. Currency: USD (see the README).
-- Depends on: staging.applovin.advertiser_campaign_report
--
-- Built from the campaign-level report, which carries all of a campaign's
-- traffic. ROAS is cohort revenue over spend for the same day: day-7 ROAS is NULL
-- until seven days have passed. Rates are ratios of sums at this grain. To report
-- a week or a month, re-sum the base columns and divide again.

SELECT
    date_day,
    campaign_id,
    MAX(campaign_name)          AS campaign_name,
    MAX(campaign_type)          AS campaign_type,
    MAX(campaign_bid_goal)      AS campaign_bid_goal,
    MAX(app_package_name)       AS app_package_name,
    MAX(app_store_id)           AS app_store_id,

    SUM(spend)                  AS spend,
    SUM(impressions)            AS impressions,
    SUM(clicks)                 AS clicks,
    SUM(installs)               AS installs,
    SUM(sales)                  AS sales,
    SUM(total_revenue_d0)       AS total_revenue_d0,
    SUM(total_revenue_d7)       AS total_revenue_d7,
    SUM(iap_revenue_d7)         AS iap_revenue_d7,
    SUM(ad_revenue_d7)          AS ad_revenue_d7,
    COUNT(DISTINCT creative_set_name) AS active_creative_sets,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))       AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))             AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000 AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(installs))           AS cpi,
    SAFE_DIVIDE(SUM(installs), SUM(clicks))          AS install_rate,
    SAFE_DIVIDE(SUM(total_revenue_d0), SUM(spend))   AS roas_d0,
    SAFE_DIVIDE(SUM(total_revenue_d7), SUM(spend))   AS roas_d7
FROM {{ ref('stg_applovin__advertiser_campaign_report') }}
GROUP BY 1, 2
