-- core.microsoft_ads.ad_group_report
-- Daily Microsoft Advertising delivery per ad group, split by device and
-- network, labelled with its campaign and account.
--
-- Grain: day x ad group x device OS x device type x network x currency.
-- Dates are the report dates Microsoft Advertising returns, in the account's
-- time zone. Spend is in currency_code. conversions and revenue are
-- Microsoft's own attributed figures.
--
-- Built from the ad-level daily report rolled up to the ad group.
--
-- Depends on: raw.microsoft_ads.ad_performance_daily_report, ad_group,
--             campaign, account
--
-- From the weld.app template library, rewritten. Not reconciled against
-- Microsoft Ads; check the output against the source before relying on it.

WITH delivery AS (
    SELECT
        date                                        AS date_day,
        account_id,
        campaign_id,
        ad_group_id,
        device_os,
        device_type,
        network,
        currency_code,
        SUM(impressions)                            AS impressions,
        SUM(clicks)                                 AS clicks,
        SUM(spend)                                  AS spend,
        SUM(conversions)                            AS conversions,
        SUM(revenue)                                AS revenue
    FROM {{raw.microsoft_ads.ad_performance_daily_report}}
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

ad_group_lookup AS (
    SELECT id AS ad_group_id, ad_group AS ad_group_name
    FROM {{raw.microsoft_ads.ad_group}}
),

campaign_lookup AS (
    SELECT id AS campaign_id, campaign AS campaign_name
    FROM {{raw.microsoft_ads.campaign}}
),

account_lookup AS (
    SELECT id AS account_id, name AS account_name
    FROM {{raw.microsoft_ads.account}}
)

SELECT
    d.date_day,
    d.account_id,
    a.account_name,
    d.campaign_id,
    c.campaign_name,
    d.ad_group_id,
    g.ad_group_name,
    d.currency_code,
    d.network,
    d.device_type,
    d.device_os,
    d.impressions,
    d.clicks,
    d.spend,
    d.conversions,
    d.revenue
FROM delivery d
LEFT JOIN ad_group_lookup g
  ON g.ad_group_id = d.ad_group_id
LEFT JOIN campaign_lookup c
  ON c.campaign_id = d.campaign_id
LEFT JOIN account_lookup a
  ON a.account_id = d.account_id
