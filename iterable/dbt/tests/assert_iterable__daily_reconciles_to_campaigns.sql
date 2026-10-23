-- The daily series and the campaign table count the same sends, opens and clicks.
--
-- Both models read the same event tables, one split by day and one not. Their totals per
-- campaign must agree; a gap means a join fanned out or an event table was dropped from
-- one of them. Unique counts are left out because they are per day in one model and per
-- campaign in the other.

WITH daily AS (
    SELECT campaign_id, SUM(sends) AS sends, SUM(opens) AS opens, SUM(clicks) AS clicks,
           SUM(bounces) AS bounces
    FROM {{ ref('core_iterable__email_performance_daily') }}
    WHERE campaign_id IS NOT NULL
    GROUP BY 1
)

SELECT c.campaign_id, c.sends, d.sends AS daily_sends, c.opens, d.opens AS daily_opens
FROM {{ ref('core_iterable__email_campaign_performance') }} c
JOIN daily d ON d.campaign_id = c.campaign_id
WHERE c.sends != d.sends
   OR c.opens != d.opens
   OR c.clicks != d.clicks
   OR c.bounces != d.bounces
