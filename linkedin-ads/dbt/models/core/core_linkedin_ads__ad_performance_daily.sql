-- core_linkedin_ads__ad_performance_daily
-- Daily delivery and results per creative, the Campaign Manager "Ads" view by day.
-- LinkedIn calls an ad a creative, so ad_id is the creative id.
--
-- Grain: date_day x account_id x ad_id. Currency: the ad account's.
-- Depends on: staging.linkedin_ads.creative_analytics, .creative, .campaign,
--             .campaign_group, .account
--
-- Hierarchy: account > campaign group > campaign > creative. LinkedIn has no level
-- between campaign and ad, so the grouping columns carried here are the campaign
-- group's.
--
-- Conversion definition: conversions = external website conversions, post-click
-- plus post-view, under the attribution windows set on each conversion rule in
-- Campaign Manager (LinkedIn's defaults are 30 days after a click and 7 days after
-- a view). This matches the "Conversions" column in Campaign Manager. Lead Gen
-- Form submissions are NOT included; they are in `leads` (one-click leads), with
-- their own cost_per_lead. conversion_value is the value LinkedIn attributes to
-- website conversions, NULL when no conversion rule carries a value.
--
-- Rates are ratios of the row's own sums. Re-sum the base columns and divide again
-- for any other period or level.

WITH perf AS (
    SELECT
        d.date_day,
        cr.account_id,
        acc.account_name,
        acc.currency,
        cr.campaign_id,
        c.campaign_name,
        c.campaign_group_id,
        g.campaign_group_name,
        d.creative_id                    AS ad_id,
        cr.creative_title                AS ad_name,
        c.objective_type                 AS campaign_objective,
        c.campaign_type,
        cr.intended_status               AS ad_status,
        d.spend,
        d.impressions,
        d.clicks,
        d.website_conversions            AS conversions,
        d.conversion_value,
        d.spend_usd,
        d.landing_page_clicks,
        d.website_post_click_conversions,
        d.website_post_view_conversions,
        d.leads,
        d.lead_form_opens,
        d.engagements,
        d.video_views
    FROM {{ ref('stg_linkedin_ads__creative_analytics') }} d
    -- The analytics table has no account column, so the first join is on the
    -- creative id alone (LinkedIn creative ids are unique across accounts). Every
    -- join after that carries account_id. Each staging entity is one row per id,
    -- so no join can fan out. LEFT JOINs keep spend for creatives missing from the
    -- entity tables, with NULL names.
    LEFT JOIN {{ ref('stg_linkedin_ads__creative') }} cr
        ON cr.creative_id = d.creative_id
    LEFT JOIN {{ ref('stg_linkedin_ads__campaign') }} c
        ON c.account_id = cr.account_id
       AND c.campaign_id = cr.campaign_id
    LEFT JOIN {{ ref('stg_linkedin_ads__campaign_group') }} g
        ON g.account_id = c.account_id
       AND g.campaign_group_id = c.campaign_group_id
    LEFT JOIN {{ ref('stg_linkedin_ads__account') }} acc
        ON acc.account_id = cr.account_id
)

SELECT
    date_day,
    account_id,
    account_name,
    currency,
    campaign_id,
    campaign_name,
    campaign_group_id,
    campaign_group_name,
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

    'linkedin_ads'                          AS source,
    campaign_objective,
    campaign_type,
    ad_status,
    spend_usd,
    landing_page_clicks,
    website_post_click_conversions,
    website_post_view_conversions,
    leads,
    SAFE_DIVIDE(spend, leads)               AS cost_per_lead,
    lead_form_opens,
    engagements,
    video_views
FROM perf
