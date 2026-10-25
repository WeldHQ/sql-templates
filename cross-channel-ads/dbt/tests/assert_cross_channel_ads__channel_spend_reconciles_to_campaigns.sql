-- The channel overview must carry exactly the campaign table's spend, per day,
-- platform and currency.
-- Returns zero rows when they agree; a cent of tolerance absorbs rounding.

WITH campaigns AS (
    SELECT date_day, source, currency, SUM(spend) AS spend
    FROM {{ ref('core_cross_channel_ads__campaign_performance_daily') }}
    GROUP BY 1, 2, 3
)

SELECT
    c.date_day,
    c.source,
    c.currency,
    c.spend   AS campaign_spend,
    ch.spend  AS channel_spend
FROM campaigns c
FULL OUTER JOIN {{ ref('core_cross_channel_ads__channel_performance_daily') }} ch
  ON ch.date_day = c.date_day
 AND ch.source = c.source
 AND ch.currency IS NOT DISTINCT FROM c.currency
WHERE ABS(COALESCE(c.spend, 0) - COALESCE(ch.spend, 0)) > 0.01
