-- One row per deal in deal_activity.
--
-- The model joins activity-to-deal links to the activity and to the deal. If
-- either side ever held two rows for one key, every count for that deal would
-- silently double.

SELECT hubspot_portal, deal_id, COUNT(*) AS row_count
FROM {{ ref('core_hubspot_v2__deal_activity') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
