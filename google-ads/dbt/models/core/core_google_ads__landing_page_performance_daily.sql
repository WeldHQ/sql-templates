-- core_google_ads__landing_page_performance_daily
-- Daily spend, clicks and conversions per landing page, so ad traffic can be set
-- against sessions and orders in web analytics.
--
-- Grain: date_day x account_id x campaign_id x landing_page.
-- Currency: the account's. Depends on: core.google_ads.ad_performance_daily
--
-- landing_page is the ad's first final URL with any query string or fragment
-- removed, so URL variants of one page land together. The full final URL and the
-- effective final URL suffix (where UTM tags usually live) are on
-- ad_performance_daily. Ads without a final URL (some app and video ads) show
-- as a NULL landing page. Ad level only: Performance Max is not in it.

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    REGEXP_REPLACE(final_url, r'[?#].*$', '')      AS landing_page,
    COUNT(DISTINCT ad_id)                          AS ads,
    SUM(spend)                                     AS spend,
    SUM(impressions)                               AS impressions,
    SUM(clicks)                                    AS clicks,
    SUM(conversions)                               AS conversions,
    SUM(conversion_value)                          AS conversion_value,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))     AS ctr,
    SAFE_DIVIDE(SUM(spend), SUM(clicks))           AS cpc,
    SAFE_DIVIDE(SUM(spend), SUM(conversions))      AS cost_per_conversion,
    SAFE_DIVIDE(SUM(conversion_value), SUM(spend)) AS roas
FROM {{ ref('core_google_ads__ad_performance_daily') }}
GROUP BY 1, 2, 3, 4, 5, 6, 7
