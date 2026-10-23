-- One row per post in content_inventory.
-- The featured-image and revision joins are pre-aggregated to one row per post; if
-- either stops being unique (for example by joining postmeta directly), posts are
-- duplicated and every count in a dashboard is inflated.

SELECT
    post_id,
    COUNT(*) AS row_count
FROM {{ ref('core_wordpress__content_inventory') }}
GROUP BY 1
HAVING COUNT(*) > 1
