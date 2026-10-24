-- The two AppLovin reports are synced separately: spend summed over creative sets
-- must equal campaign spend, day by day and per campaign. A gap means rows were
-- lost in one of the reports (for example ads that share a creative set, ad type
-- and placement on the same day) or one stream is behind the other.
-- Returns zero rows when they agree; a cent of tolerance absorbs rounding.

WITH creative_sets AS (
    SELECT date_day, campaign_id, SUM(spend) AS spend
    FROM {{ ref('core_applovin__ad_performance_daily') }}
    GROUP BY 1, 2
),

campaigns AS (
    SELECT date_day, campaign_id, spend
    FROM {{ ref('core_applovin__campaign_performance_daily') }}
)

SELECT
    COALESCE(s.date_day, c.date_day)       AS date_day,
    COALESCE(s.campaign_id, c.campaign_id) AS campaign_id,
    s.spend AS creative_set_spend,
    c.spend AS campaign_spend
FROM creative_sets s
FULL OUTER JOIN campaigns c USING (date_day, campaign_id)
WHERE ABS(COALESCE(s.spend, 0) - COALESCE(c.spend, 0)) > 0.01
