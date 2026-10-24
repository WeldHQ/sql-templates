-- core_microsoft_ads__campaign_report
-- Daily Microsoft Advertising delivery per campaign, split by device and
-- network, with the campaign's type and current status.
--
-- Grain: day x campaign x device OS x device type x network x currency.
-- Dates are the report dates Microsoft Advertising returns, in the account's
-- time zone. Spend is in currency_code. campaign_status is the campaign's
-- status today, not on the report date. conversions and revenue are
-- Microsoft's own attributed figures.
--
-- Depends on: raw.microsoft_ads.campaign_performance_daily_report, campaign,
--             account
--
-- From the weld.app template library, rewritten. Not reconciled against
-- Microsoft Ads; check the output against the source before relying on it.

WITH delivery AS (
    SELECT
        date                                        AS date_day,
        account_id,
        campaign_id,
        device_os,
        device_type,
        network,
        currency_code,
        SUM(impressions)                            AS impressions,
        SUM(clicks)                                 AS clicks,
        SUM(spend)                                  AS spend,
        SUM(conversions)                            AS conversions,
        SUM(revenue)                                AS revenue
    FROM {{ source('microsoft_ads', 'campaign_performance_daily_report') }}
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),

campaign_lookup AS (
    SELECT
        id                                          AS campaign_id,
        campaign                                    AS campaign_name,
        campaign_type,
        status                                      AS campaign_status
    FROM {{ source('microsoft_ads', 'campaign') }}
),

account_lookup AS (
    SELECT id AS account_id, name AS account_name
    FROM {{ source('microsoft_ads', 'account') }}
)

SELECT
    d.date_day,
    d.account_id,
    a.account_name,
    d.campaign_id,
    c.campaign_name,
    c.campaign_type,
    c.campaign_status,
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
LEFT JOIN campaign_lookup c
  ON c.campaign_id = d.campaign_id
LEFT JOIN account_lookup a
  ON a.account_id = d.account_id
