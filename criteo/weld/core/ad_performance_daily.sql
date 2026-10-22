-- core.criteo.ad_performance_daily
-- Daily delivery and sales results per ad, the Criteo Commerce Growth ad report
-- by day.
--
-- Grain: date_day x campaign_id x adset_id x ad_id. Spend that Criteo cannot tie
-- to an ad arrives under ad_id "-1", once per ad set; it is kept, so totals match
-- the campaign view in Criteo.
-- Currency: the one chosen in the connector settings, the same for every advertiser.
-- Depends on: staging.criteo.ad_statistics_daily, .campaign, .adset, .ad, .advertiser
--
-- The first twelve columns are the cross-channel ad contract (date_day,
-- account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
-- impressions, clicks, conversions, conversion_value) shared with the other paid
-- ads templates in this repo, so they can be stacked with UNION ALL.
--
-- conversions = sales attributed post-click within 30 days, same device
-- (Criteo's SalesPc30d); conversion_value is the matching revenue. Cross-device,
-- post-view and your own (client) attribution are kept as extra columns. Swap
-- them into conversions if your Criteo account reports on another model.

SELECT
    s.date_day,
    COALESCE(c.account_id, g.account_id, a.account_id) AS account_id,
    adv.account_name,
    s.campaign_id,
    COALESCE(c.campaign_name, s.campaign_name)         AS campaign_name,
    s.ad_id,
    COALESCE(a.ad_name, s.ad_name)                     AS ad_name,
    s.spend,
    s.impressions,
    s.clicks,
    s.sales_pc_30d                                     AS conversions,
    s.revenue_pc_30d                                   AS conversion_value,

    'criteo'                                           AS source,
    s.currency,
    s.adset_id,
    COALESCE(g.adset_name, s.adset_name)               AS adset_name,
    c.campaign_goal,
    g.objective                                        AS adset_objective,
    a.creative_id,
    s.sales_all_pc_30d,
    s.revenue_all_pc_30d,
    s.sales_pv_24h,
    s.revenue_pv_24h,
    s.sales_client_attribution,
    s.revenue_client_attribution,
    s.visits
FROM {{staging.criteo.ad_statistics_daily}} s
-- Entity tables are one row per id after staging, so these joins cannot fan out.
-- LEFT JOINs: the "-1" placeholder ad and deleted entities keep their spend.
LEFT JOIN {{staging.criteo.campaign}}   c   ON c.campaign_id = s.campaign_id
LEFT JOIN {{staging.criteo.adset}}      g   ON g.adset_id = s.adset_id
LEFT JOIN {{staging.criteo.ad}}         a   ON a.ad_id = s.ad_id
LEFT JOIN {{staging.criteo.advertiser}} adv
    ON adv.account_id = COALESCE(c.account_id, g.account_id, a.account_id)
