-- stg_asana__project_task
-- Thin wrapper over raw `project_task`. One row per task x project membership.
-- A task can belong to several projects.

SELECT DISTINCT
    CAST(task_gid AS STRING)    AS task_id,
    CAST(project_gid AS STRING) AS project_id
FROM {{ source('asana', 'project_task') }}
WHERE task_gid IS NOT NULL
  AND project_gid IS NOT NULL
