-- One row per campaign x creator. A duplicate means one of the per-source
-- aggregates fanned out, and every revenue and cost figure on the row is inflated.

SELECT grin_account, campaign_id, contact_id, COUNT(*) AS rows_per_key
FROM {{ ref('core_grin__creator_campaign_performance') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
