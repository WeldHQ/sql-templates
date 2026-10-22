-- core.reddit_ads.ad_performance_daily
-- Daily delivery and purchase results per ad, the Ads Manager "Ads" tab by day.
--
-- Grain: date_day x account_id x ad_id. Currency: the ad account's.
-- Depends on: staging.reddit_ads.ad_performance, .ad, .ad_group, .campaign, .ad_account
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the other paid
-- ads templates in this repo, so they can be stacked with UNION ALL.
--
-- conversions = purchase click-through + view-through conversions, which is what
-- Ads Manager shows as "Purchases" under the account's attribution windows.
-- conversion_value is the matching purchase value. Both are dated on the day of
-- the ad interaction, not the day of the purchase, and Reddit keeps updating them
-- as late conversions arrive.

WITH daily AS (
    -- SUM, not pick-one: with a non-UTC report timezone a local date is spread
    -- over two UTC request windows.
    SELECT
        date_day,
        account_id,
        ad_id,
        SUM(impressions)                AS impressions,
        SUM(clicks)                     AS clicks,
        SUM(spend)                      AS spend,
        SUM(purchase_click_conversions) AS purchase_click_conversions,
        SUM(purchase_view_conversions)  AS purchase_view_conversions,
        SUM(purchase_value)             AS purchase_value
    FROM {{staging.reddit_ads.ad_performance}}
    GROUP BY 1, 2, 3
)

SELECT
    d.date_day,
    d.account_id,
    acc.account_name,
    a.campaign_id,
    c.campaign_name,
    d.ad_id,
    a.ad_name,
    d.spend,
    d.impressions,
    d.clicks,
    d.purchase_click_conversions + d.purchase_view_conversions AS conversions,
    d.purchase_value                                           AS conversion_value,

    'reddit_ads'                     AS source,
    acc.currency,
    a.ad_group_id,
    g.ad_group_name,
    c.objective                      AS campaign_objective,
    d.purchase_click_conversions,
    d.purchase_view_conversions
FROM daily d
-- Entity tables are one row per id after staging, so these joins cannot fan out.
-- LEFT JOINs: an ad deleted in Reddit keeps its spend, with NULL names.
LEFT JOIN {{staging.reddit_ads.ad}}         a   ON a.ad_id = d.ad_id
LEFT JOIN {{staging.reddit_ads.ad_group}}   g   ON g.ad_group_id = a.ad_group_id
LEFT JOIN {{staging.reddit_ads.campaign}}   c   ON c.campaign_id = a.campaign_id
LEFT JOIN {{staging.reddit_ads.ad_account}} acc ON acc.account_id = d.account_id
