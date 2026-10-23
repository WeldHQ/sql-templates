-- One row per campaign in campaign_performance, and one per day x audience in
-- audience_growth_daily.
--
-- campaign_performance joins six inputs; if any of them stops being one row per campaign
-- the metrics multiply silently. list_activity is restated by Mailchimp and can land a day
-- twice; staging keeps the latest copy. This checks both grains.

SELECT 'campaign_performance' AS model, campaign_id AS key, COUNT(*) AS row_count
FROM {{ ref('core_mailchimp__campaign_performance') }}
GROUP BY campaign_id
HAVING COUNT(*) > 1

UNION ALL

SELECT 'audience_growth_daily', CONCAT(list_id, ' / ', CAST(day AS STRING)), COUNT(*)
FROM {{ ref('core_mailchimp__audience_growth_daily') }}
GROUP BY list_id, day
HAVING COUNT(*) > 1
