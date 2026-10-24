-- One row per case. A duplicate means a re-synced case version was kept twice, or
-- the group lookup stopped being one row per group.
-- Returns zero rows when the grain holds.

SELECT case_id, COUNT(*) AS row_count
FROM {{ ref('core_sprout_social__case_resolution') }}
GROUP BY 1
HAVING COUNT(*) > 1
