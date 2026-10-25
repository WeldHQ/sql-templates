-- core_google_ads__campaign_performance_daily
-- Daily campaign performance with the rates the Google Ads UI shows: CTR, CPC,
-- CPM, cost per conversion and ROAS.
--
-- Grain: date_day x account_id x campaign_id. Currency: the account's.
-- Depends on: staging.google_ads.campaign_stats, .campaign, .account
--
-- Read from the campaign report, not summed from ad_performance_daily: Google's
-- ad level report leaves out campaigns that have no ads in the classic sense
-- (Performance Max, Smart, some App campaigns), so only the campaign report ties
-- to account spend.
--
-- conversions follows the same definition as ad_performance_daily: primary
-- conversion actions, each action's own attribution model and window, dated on
-- the interaction day. Rates are ratios of sums; to report a week or a month,
-- re-sum the base columns and divide again.

WITH daily AS (
    SELECT
        date_day,
        account_id,
        campaign_id,
        MAX(account_name)             AS report_account_name,
        MAX(campaign_name)            AS report_campaign_name,
        SUM(spend)                    AS spend,
        SUM(impressions)              AS impressions,
        SUM(clicks)                   AS clicks,
        SUM(interactions)             AS interactions,
        SUM(conversions)              AS conversions,
        SUM(conversion_value)         AS conversion_value,
        SUM(view_through_conversions) AS view_through_conversions,
        SUM(video_views)              AS video_views
    FROM {{ ref('stg_google_ads__campaign_stats') }}
    GROUP BY 1, 2, 3
)

SELECT
    d.date_day,
    d.account_id,
    COALESCE(acc.account_name, d.report_account_name) AS account_name,
    acc.currency,
    d.campaign_id,
    COALESCE(c.campaign_name, d.report_campaign_name) AS campaign_name,
    d.spend,
    d.impressions,
    d.clicks,
    d.conversions,
    d.conversion_value,
    SAFE_DIVIDE(d.clicks, d.impressions)              AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)                    AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000        AS cpm,
    SAFE_DIVIDE(d.spend, d.conversions)               AS cost_per_conversion,
    SAFE_DIVIDE(d.conversion_value, d.spend)          AS roas,

    'google_ads'                                      AS source,
    c.channel_type                                    AS campaign_channel_type,
    c.campaign_status,
    d.interactions,
    d.view_through_conversions,
    d.video_views
FROM daily d
LEFT JOIN {{ ref('stg_google_ads__campaign') }} c
       ON c.account_id = d.account_id AND c.campaign_id = d.campaign_id
LEFT JOIN {{ ref('stg_google_ads__account') }}  acc
       ON acc.account_id = d.account_id
