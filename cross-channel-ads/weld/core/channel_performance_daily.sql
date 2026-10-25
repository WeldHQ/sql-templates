-- core.cross_channel_ads.channel_performance_daily
-- One row per platform, currency and day: the paid media overview a marketing
-- team reads first. Share of spend is within the day and currency.
--
-- Grain: date_day x source x currency.
-- Depends on: core.cross_channel_ads.campaign_performance_daily
--
-- Rates are ratios of sums at this grain. To report a week or a month, re-sum the
-- base columns and divide again; averaging the daily rates weights a quiet day the
-- same as a busy one. Conversions keep each platform's own definition (see the
-- campaign model), so cost_per_conversion compares a platform with itself over
-- time, not one platform with another.

WITH daily AS (
    SELECT
        date_day,
        source,
        currency,
        SUM(spend)                   AS spend,
        SUM(impressions)             AS impressions,
        SUM(clicks)                  AS clicks,
        SUM(conversions)             AS conversions,
        SUM(conversion_value)        AS conversion_value,
        COUNT(DISTINCT account_id)   AS accounts,
        COUNT(DISTINCT IF(spend > 0, campaign_id, NULL)) AS campaigns_with_spend
    FROM {{core.cross_channel_ads.campaign_performance_daily}}
    GROUP BY 1, 2, 3
)

SELECT
    date_day,
    source,
    currency,
    spend,
    impressions,
    clicks,
    conversions,
    conversion_value,
    accounts,
    campaigns_with_spend,
    SAFE_DIVIDE(spend, SUM(spend) OVER (PARTITION BY date_day, currency)) AS share_of_spend,
    SAFE_DIVIDE(clicks, impressions)          AS ctr,
    SAFE_DIVIDE(spend, clicks)                AS cpc,
    SAFE_DIVIDE(spend, impressions) * 1000    AS cpm,
    SAFE_DIVIDE(spend, conversions)           AS cost_per_conversion,
    SAFE_DIVIDE(conversion_value, spend)      AS roas
FROM daily
