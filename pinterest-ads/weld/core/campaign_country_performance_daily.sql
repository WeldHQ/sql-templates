-- core.pinterest_ads.campaign_country_performance_daily
-- Daily campaign performance by the viewer's country, the Ads Manager country
-- breakdown.
--
-- Grain: date_day x account_id x campaign_id x country_code. Currency: the ad
-- account's.
-- Depends on: staging.pinterest_ads.campaign_country_report, .campaign, .ad_account
--
-- Read from Pinterest's own country report, not summed from ads: the ad report has
-- no country dimension. Same conversion definitions as ad_performance_daily
-- (all conversion events; checkout value; default attribution windows).
--
-- Pinterest only reports a country when it can resolve one, so the country rows of
-- a campaign day can sum to less than campaign_performance_daily for that day.
-- Use this model for shares and comparisons between countries, the campaign
-- model for totals.

SELECT
    r.date_day,
    r.account_id,
    acc.account_name,
    acc.currency,
    r.campaign_id,
    COALESCE(c.campaign_name, r.report_campaign_name) AS campaign_name,
    r.country_code,

    r.spend,
    r.impressions,
    r.clicks,
    r.conversions,
    r.checkout_value                                   AS conversion_value,

    SAFE_DIVIDE(r.clicks, r.impressions)               AS ctr,
    SAFE_DIVIDE(r.spend, r.clicks)                     AS cpc,
    SAFE_DIVIDE(r.spend, r.impressions) * 1000         AS cpm,
    SAFE_DIVIDE(r.spend, r.conversions)                AS cost_per_conversion,
    SAFE_DIVIDE(r.checkout_value, r.spend)             AS roas
FROM {{staging.pinterest_ads.campaign_country_report}} r
LEFT JOIN {{staging.pinterest_ads.campaign}} c
    ON c.account_id = r.account_id
   AND c.campaign_id = r.campaign_id
LEFT JOIN {{staging.pinterest_ads.ad_account}} acc
    ON acc.account_id = r.account_id
