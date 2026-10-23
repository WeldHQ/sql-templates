-- One row per project and flag key in flag_inventory.
-- Flag keys repeat across projects; if this fails, a join dropped project_id from
-- its key and every project-level count downstream is inflated.

SELECT
    project_id,
    flag_key,
    COUNT(*) AS row_count
FROM {{ ref('core_launchdarkly__flag_inventory') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
