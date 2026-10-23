-- The per-project totals add up to the flag inventory, and the lifecycle buckets
-- add up to the total. A mismatch means a lifecycle status was added to
-- flag_inventory without a matching column in flag_health_by_project.

WITH inventory AS (
    SELECT COUNT(*) AS flags FROM {{ ref('core_launchdarkly__flag_inventory') }}
),

projects AS (
    SELECT
        SUM(flags_total) AS flags_total,
        SUM(flags_live_temporary + flags_live_permanent + flags_deprecated + flags_archived) AS flags_bucketed
    FROM {{ ref('core_launchdarkly__flag_health_by_project') }}
)

SELECT *
FROM inventory, projects
WHERE inventory.flags != projects.flags_total
   OR projects.flags_total != projects.flags_bucketed
