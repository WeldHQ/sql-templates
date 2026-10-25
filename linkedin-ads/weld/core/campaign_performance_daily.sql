-- core.linkedin_ads.campaign_performance_daily
-- Daily campaign performance with the rates Campaign Manager shows: CTR, CPC, CPM,
-- cost per conversion, ROAS and cost per lead.
--
-- Grain: date_day x account_id x campaign_id. Currency: the ad account's.
-- Depends on: core.linkedin_ads.ad_performance_daily
--
-- Built by summing creatives, so it uses the same conversion definition: external
-- website conversions (post-click plus post-view, per conversion rule windows),
-- with Lead Gen Form leads kept apart in `leads`.
--
-- Rates are ratios of sums at this grain; never average the daily rates.

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    campaign_group_id,
    campaign_group_name,
    campaign_objective,

    SUM(spend)            AS spend,
    SUM(impressions)      AS impressions,
    SUM(clicks)           AS clicks,
    SUM(conversions)      AS conversions,
    SUM(conversion_value) AS conversion_value,

    SAFE_DIVIDE(SUM(clicks), SUM(impressions))             AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))                   AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(impressions)) * 1000       AS cpm,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))              AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend))         AS roas,

    'linkedin_ads'        AS source,
    SUM(spend_usd)        AS spend_usd,
    SUM(landing_page_clicks) AS landing_page_clicks,
    SUM(leads)            AS leads,
    SAFE_DIVIDE(SUM(spend), SUM(leads))                    AS cost_per_lead,
    SUM(lead_form_opens)  AS lead_form_opens,
    COUNT(DISTINCT IF(impressions > 0, ad_id, NULL))       AS ads_with_impressions
FROM {{core.linkedin_ads.ad_performance_daily}}
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
