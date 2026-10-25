-- core_linkedin_ads__campaign_group_performance_daily
-- Daily performance per campaign group. Campaign groups hold the shared budget and
-- schedule on LinkedIn, so this is the level many teams plan and pace spend at.
--
-- Grain: date_day x account_id x campaign_group_id. Currency: the ad account's.
-- Depends on: core.linkedin_ads.campaign_performance_daily
--
-- Same conversion definition as the campaign model: external website conversions,
-- with Lead Gen Form leads in `leads`. Rates are ratios of sums at this grain.

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_group_id,
    campaign_group_name,

    SUM(spend)            AS spend,
    SUM(impressions)      AS impressions,
    SUM(clicks)           AS clicks,
    SUM(conversions)      AS conversions,
    SUM(conversion_value) AS conversion_value,
    SUM(leads)            AS leads,
    COUNT(DISTINCT IF(impressions > 0, campaign_id, NULL)) AS campaigns_with_impressions,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))             AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))                   AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000       AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))              AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))         AS roas,
    SAFE_DIVIDE(SUM(spend), SUM(leads))                    AS cost_per_lead
FROM {{ ref('core_linkedin_ads__campaign_performance_daily') }}
GROUP BY 1, 2, 3, 4, 5, 6
