-- staging.asana.task
-- Thin wrapper over raw `task`. One row per task, latest version.
--
-- The connector reads tasks per assignee and keys the raw table on task, workspace
-- AND assignee. A reassigned task therefore leaves its old row behind under the
-- previous assignee. The QUALIFY keeps only the most recently modified version of
-- each task, which carries the current assignee.
--
-- Unassigned tasks are never synced: Asana's task list endpoint is called once per
-- user, filtered on that user as assignee.
--
-- Rows with resource_subtype 'section' are dropped. They are section headers from
-- Asana's older list layout that the API still returns as tasks; they are never
-- done or overdue and would inflate every open count. Milestones and approvals
-- are kept.

SELECT
    CAST(gid AS STRING)                         AS task_id,
    CAST(workspace_gid AS STRING)               AS workspace_id,
    CAST(name AS STRING)                        AS task_name,
    LOWER(CAST(resource_subtype AS STRING))     AS resource_subtype,
    CAST(parent_gid AS STRING)                  AS parent_task_id,
    CAST(assignee_gid AS STRING)                AS assignee_id,
    LOWER(CAST(assignee_status AS STRING))      AS assignee_status,
    COALESCE(completed, FALSE)                  AS is_completed,
    CAST(completed_at AS TIMESTAMP)             AS completed_at,
    CAST(completed_by_gid AS STRING)            AS completed_by_id,
    CAST(created_by_gid AS STRING)              AS created_by_id,
    -- due_on is a calendar date in the workspace's sense; due_at is set only when
    -- a time was given, and then due_on is its date.
    COALESCE(SAFE_CAST(CAST(due_on AS STRING) AS DATE), DATE(CAST(due_at AS TIMESTAMP))) AS due_on,
    CAST(due_at AS TIMESTAMP)                   AS due_at,
    DATE(CAST(start_on AS TIMESTAMP))           AS start_on,
    CAST(modified_at AS TIMESTAMP)              AS modified_at,
    CAST(num_likes AS INT64)                    AS num_likes
FROM {{raw.asana.task}}
WHERE gid IS NOT NULL
  AND COALESCE(LOWER(CAST(resource_subtype AS STRING)), '') != 'section'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(gid AS STRING)
    ORDER BY CAST(modified_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
