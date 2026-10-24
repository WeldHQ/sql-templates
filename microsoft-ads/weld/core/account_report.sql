-- core.microsoft_ads.account_report
-- Daily Microsoft Advertising delivery per ad account, split by device and
-- network, with the account's name and time zone.
--
-- Grain: day x account x device OS x device type x network x currency.
-- Dates are the report dates Microsoft Advertising returns, in the account's
-- own time zone (account_timezone). Spend is in currency_code.
-- conversions and revenue are Microsoft's own attributed figures.
--
-- Built from the ad-level daily report, so it counts delivery that Microsoft
-- attributes to an ad. Check it against the account report in the Microsoft
-- Advertising UI before relying on it.
--
-- Depends on: raw.microsoft_ads.ad_performance_daily_report, account
--
-- From the weld.app template library, rewritten. Not reconciled against
-- Microsoft Ads; check the output against the source before relying on it.

WITH delivery AS (
    SELECT
        date                                        AS date_day,
        account_id,
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
    GROUP BY 1, 2, 3, 4, 5, 6
),

account_lookup AS (
    SELECT id AS account_id, name AS account_name, time_zone AS account_timezone
    FROM {{raw.microsoft_ads.account}}
)

SELECT
    d.date_day,
    d.account_id,
    a.account_name,
    a.account_timezone,
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
LEFT JOIN account_lookup a
  ON a.account_id = d.account_id
