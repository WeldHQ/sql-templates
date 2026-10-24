-- In project_overview, completed + open = all tasks, and overdue is a subset of
-- open. Returns zero rows when both hold.

SELECT project_id, tasks, completed_tasks, open_tasks, overdue_tasks
FROM {{ ref('core_asana__project_overview') }}
WHERE completed_tasks + open_tasks != tasks
   OR overdue_tasks > open_tasks
