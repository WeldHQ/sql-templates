-- core_snapchat_ads__ad_performance_daily
-- Daily delivery and purchase results per ad, the Ads Manager "Ads" view by day.
--
-- Grain: date_day x account_id x ad_id. Currency: the ad account's.
-- Depends on: staging.snapchat_ads.ad_daily_report, .ad, .ad_squad, .campaign, .ad_account
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the other paid
-- ads templates in this repo, so they can be stacked with UNION ALL.
--
-- In Snapchat terms: clicks are swipe ups, and the ad set level is the ad squad.
--
-- conversions = purchases reported by the Snap Pixel, app events and the
-- Conversions API, under Snapchat's default attribution: 28 days after a swipe
-- up plus 1 day after a view, counted together. conversion_value is the matching
-- purchase value. Snapchat keeps restating both until about 48 hours after the
-- day ends.
--
-- date_day is the ad account's own reporting day, the same day Ads Manager shows.

WITH daily AS (
    SELECT
        r.*,
        -- Snapchat days start at midnight in the account timezone. Without a
        -- timezone, fall back to the UTC date of that instant.
        COALESCE(
            DATE(r.report_start_at, acc.account_timezone),
            DATE(r.report_start_at)
        ) AS date_day
    FROM {{ ref('stg_snapchat_ads__ad_daily_report') }} r
    LEFT JOIN {{ ref('stg_snapchat_ads__ad_account') }} acc
        ON acc.account_id = r.account_id
)

SELECT
    d.date_day,
    d.account_id,
    acc.account_name,
    sq.campaign_id,
    c.campaign_name,
    d.ad_id,
    a.ad_name,
    CAST(d.spend AS FLOAT64)                  AS spend,
    d.impressions,
    d.swipes                                  AS clicks,
    CAST(d.purchase_conversions AS FLOAT64)   AS conversions,
    CAST(d.purchase_value AS FLOAT64)         AS conversion_value,

    'snapchat_ads'                            AS source,
    acc.currency,
    a.ad_squad_id,
    sq.ad_squad_name,
    c.campaign_objective,
    sq.optimization_goal,
    a.creative_id,
    d.video_views,
    d.video_completions,
    d.app_installs,
    d.page_view_conversions,
    d.add_to_cart_conversions,
    d.start_checkout_conversions,

    SAFE_DIVIDE(d.swipes, d.impressions)                            AS ctr,
    SAFE_DIVIDE(CAST(d.spend AS FLOAT64), d.swipes)                 AS cpc,
    SAFE_DIVIDE(CAST(d.spend AS FLOAT64), d.impressions) * 1000     AS cpm,
    SAFE_DIVIDE(CAST(d.spend AS FLOAT64), d.purchase_conversions)   AS cost_per_conversion,
    SAFE_DIVIDE(CAST(d.purchase_value AS FLOAT64), CAST(d.spend AS FLOAT64)) AS roas
FROM daily d
-- Entity tables are one row per account and id after staging, so these joins
-- cannot fan out. LEFT JOINs: an ad missing from the entity streams keeps its
-- spend, with NULL names and a NULL campaign.
LEFT JOIN {{ ref('stg_snapchat_ads__ad_account') }} acc
    ON acc.account_id = d.account_id
LEFT JOIN {{ ref('stg_snapchat_ads__ad') }} a
    ON a.account_id = d.account_id AND a.ad_id = d.ad_id
LEFT JOIN {{ ref('stg_snapchat_ads__ad_squad') }} sq
    ON sq.account_id = a.account_id AND sq.ad_squad_id = a.ad_squad_id
LEFT JOIN {{ ref('stg_snapchat_ads__campaign') }} c
    ON c.account_id = sq.account_id AND c.campaign_id = sq.campaign_id
