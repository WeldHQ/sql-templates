-- task_completion is unique on completion date x project x assignee.
-- Returns zero rows when it holds. A failure usually means project_task holds
-- duplicates that staging did not collapse.

SELECT completed_date, project_id, assignee_id, COUNT(*) AS n
FROM {{ ref('core_asana__task_completion') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
