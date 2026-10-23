-- stg_linkedin_ads__creative_report
-- Daily LinkedIn Ads delivery per creative, labelled with its campaign,
-- campaign group and ad account. The LinkedIn input to the cross-channel
-- marketing reports in google-ads/ and facebook-ads/.
--
-- Grain: day x creative. Money is in the ad account's currency
-- (cost_in_local_currency, conversion_value_in_local_currency).
-- Rates are worked out from the day's totals: ctr is clicks / impressions as a
-- fraction, cpc is spend per click, cpm is spend per thousand impressions.
-- conversions are LinkedIn's external website conversions (post-click plus
-- post-view, as LinkedIn attributes them).
--
-- Several ad accounts: Weld lands every connected account in the same tables,
-- so nothing extra is needed. For accounts synced by separate connections,
-- union their tables into each CTE below.
--
-- Depends on: raw.linkedin_ads.ad_analytics_by_creative, creative, campaign,
--             campaign_group, account
--
-- From the weld.app template library, rewritten and corrected. Not reconciled
-- against LinkedIn Ads; check the output against the source before relying on it.

WITH daily AS (
    SELECT
        CAST(date AS DATE)                                      AS date_day,
        creative_id,
        SUM(cost_in_local_currency)                             AS spend,
        SUM(impressions)                                        AS impressions,
        SUM(clicks)                                             AS clicks,
        SUM(external_website_conversions)                       AS conversions,
        SUM(conversion_value_in_local_currency)                 AS conversion_value
    FROM {{ source('linkedin_ads', 'ad_analytics_by_creative') }}
    GROUP BY 1, 2
),

creatives AS (
    SELECT
        id                                                      AS creative_id,
        title                                                   AS creative_name,
        intended_status                                         AS creative_status,
        campaign_id
    FROM {{ source('linkedin_ads', 'creative') }}
),

campaigns AS (
    SELECT
        id                                                      AS campaign_id,
        name                                                    AS campaign_name,
        status                                                  AS campaign_status,
        campaign_group_id,
        account_id
    FROM {{ source('linkedin_ads', 'campaign') }}
),

campaign_groups AS (
    SELECT
        id                                                      AS campaign_group_id,
        name                                                    AS campaign_group_name,
        status                                                  AS campaign_group_status
    FROM {{ source('linkedin_ads', 'campaign_group') }}
),

accounts AS (
    SELECT
        CAST(id AS STRING)                                      AS account_id,
        name                                                    AS account_name,
        currency
    FROM {{ source('linkedin_ads', 'account') }}
)

SELECT
    d.date_day,
    a.account_id,
    a.account_name,
    a.currency,
    g.campaign_group_id,
    g.campaign_group_name,
    g.campaign_group_status,
    c.campaign_id,
    c.campaign_name,
    c.campaign_status,
    d.creative_id,
    cr.creative_name,
    cr.creative_status,
    d.impressions,
    d.clicks,
    d.spend,
    d.conversions,
    d.conversion_value,
    SAFE_DIVIDE(d.clicks, d.impressions)                        AS ctr,
    SAFE_DIVIDE(d.spend, d.clicks)                              AS cpc,
    SAFE_DIVIDE(d.spend, d.impressions) * 1000                  AS cpm
FROM daily d
LEFT JOIN creatives cr
  ON cr.creative_id = d.creative_id
LEFT JOIN campaigns c
  ON c.campaign_id = cr.campaign_id
LEFT JOIN campaign_groups g
  ON g.campaign_group_id = c.campaign_group_id
LEFT JOIN accounts a
  ON a.account_id = CAST(c.account_id AS STRING)
