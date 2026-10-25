-- core.facebook_ads.ad_performance_daily
-- Daily delivery and purchase results per ad, the Ads Manager "Ads" tab by day.
--
-- Grain: date_day x account_id x ad_id. Currency: the ad account's.
-- Depends on: staging.facebook_ads.ad_roas_insight, .ad_roas_insight_actions,
-- .ad_roas_insight_action_values, .ad, .ad_set, .campaign, .account,
-- .ad_set_attribution
--
-- The leading columns follow the cross-channel ad contract shared with the other
-- paid ads templates in this repo, so the models can be stacked with UNION ALL.
--
-- clicks is link clicks (Ads Manager "Link clicks"), the closest match to a
-- click on a search or display ad; Meta's "Clicks (all)", which also counts
-- likes, comments and profile clicks, is in clicks_all.
--
-- conversions is purchases: Meta's omni_purchase action (the Ads Manager
-- "Purchases" column, de-duplicated across website, app and offline), falling
-- back to the purchase action where omni_purchase is absent. Never both, so a
-- purchase is not counted twice. conversion_value is the matching purchase value.
-- Both use the attribution windows the connector requests (7-day click and
-- 1-day view by default) and are dated on the day the purchase happened, not the
-- day of the ad impression. For other conversion events, see
-- conversions_by_action_type_daily.

WITH purchases AS (
    -- One row per ad and day: pick the purchase action types out of the
    -- one-row-per-action-type tables before joining, so the join cannot fan out.
    SELECT
        date_day,
        account_id,
        ad_id,
        COALESCE(SUM(IF(action_type = 'omni_purchase', action_count, NULL)),
                 SUM(IF(action_type = 'purchase', action_count, NULL)))          AS purchases
    FROM {{staging.facebook_ads.ad_roas_insight_actions}}
    WHERE action_type IN ('omni_purchase', 'purchase')
    GROUP BY 1, 2, 3
),

purchase_values AS (
    SELECT
        date_day,
        account_id,
        ad_id,
        COALESCE(SUM(IF(action_type = 'omni_purchase', action_value, NULL)),
                 SUM(IF(action_type = 'purchase', action_value, NULL)))          AS purchase_value
    FROM {{staging.facebook_ads.ad_roas_insight_action_values}}
    WHERE action_type IN ('omni_purchase', 'purchase')
    GROUP BY 1, 2, 3
),

delivery AS (
    -- The report key also holds campaign and ad set, which never change for an
    -- ad, so this is already one row per ad and day; the GROUP BY makes it certain.
    SELECT
        date_day,
        account_id,
        ad_id,
        MAX(account_name)  AS report_account_name,
        MAX(currency)      AS report_currency,
        MAX(campaign_id)   AS report_campaign_id,
        MAX(campaign_name) AS report_campaign_name,
        MAX(ad_set_id)     AS report_ad_set_id,
        MAX(ad_set_name)   AS report_ad_set_name,
        MAX(ad_name)       AS report_ad_name,
        SUM(spend)         AS spend,
        SUM(impressions)   AS impressions,
        SUM(link_clicks)   AS link_clicks,
        SUM(clicks_all)    AS clicks_all,
        SUM(reach)         AS reach
    FROM {{staging.facebook_ads.ad_roas_insight}}
    GROUP BY 1, 2, 3
)

SELECT
    d.date_day,
    d.account_id,
    COALESCE(acc.account_name, d.report_account_name)       AS account_name,
    COALESCE(acc.currency, d.report_currency)               AS currency,
    COALESCE(a.campaign_id, d.report_campaign_id)           AS campaign_id,
    COALESCE(c.campaign_name, d.report_campaign_name)       AS campaign_name,
    COALESCE(a.ad_set_id, d.report_ad_set_id)               AS ad_set_id,
    COALESCE(s.ad_set_name, d.report_ad_set_name)           AS ad_set_name,
    d.ad_id,
    COALESCE(a.ad_name, d.report_ad_name)                   AS ad_name,
    d.spend,
    d.impressions,
    d.link_clicks                                           AS clicks,
    COALESCE(p.purchases, 0)                                AS conversions,
    COALESCE(v.purchase_value, 0)                           AS conversion_value,
    SAFE_DIVIDE(d.link_clicks, d.impressions)               AS ctr,
    SAFE_DIVIDE(d.spend, d.link_clicks)                     AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000              AS cpm,
    SAFE_DIVIDE(d.spend, COALESCE(p.purchases, 0))          AS cost_per_conversion,
    SAFE_DIVIDE(COALESCE(v.purchase_value, 0), d.spend)     AS roas,

    'facebook_ads'                                          AS source,
    c.objective                                             AS campaign_objective,
    s.optimization_goal                                     AS ad_set_optimization_goal,
    attr.attribution_setting                                AS ad_set_attribution_setting,
    d.clicks_all,
    -- Reach counts unique people, so it cannot be summed across ads or days.
    d.reach
FROM delivery d
LEFT JOIN purchases p
       ON p.date_day = d.date_day AND p.account_id = d.account_id AND p.ad_id = d.ad_id
LEFT JOIN purchase_values v
       ON v.date_day = d.date_day AND v.account_id = d.account_id AND v.ad_id = d.ad_id
-- Entity tables are one row per id after staging, so these joins cannot fan out.
-- LEFT JOINs: a deleted ad keeps its spend, with the names the report carried.
LEFT JOIN {{staging.facebook_ads.ad}}                 a    ON a.ad_id = d.ad_id
LEFT JOIN {{staging.facebook_ads.ad_set}}             s    ON s.ad_set_id = COALESCE(a.ad_set_id, d.report_ad_set_id)
LEFT JOIN {{staging.facebook_ads.campaign}}           c    ON c.campaign_id = COALESCE(a.campaign_id, d.report_campaign_id)
LEFT JOIN {{staging.facebook_ads.account}}            acc  ON acc.account_id = d.account_id
LEFT JOIN {{staging.facebook_ads.ad_set_attribution}} attr ON attr.ad_set_id = COALESCE(a.ad_set_id, d.report_ad_set_id)
