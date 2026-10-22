-- core_asana__project_overview
-- One row per project: status, owner, team, task progress and overdue work.
-- Recreates the overview Asana shows on a portfolio, as of the last sync.
-- Grain: project.
--
-- Task counts only include assigned tasks, because unassigned tasks are not
-- synced (see staging.asana.task). `pct_complete` is therefore the share of
-- assigned tasks that are done, which can differ from Asana's own progress bar.

WITH task_stats AS (
    SELECT
        pt.project_id,
        COUNT(*)                                                    AS tasks,
        COUNTIF(t.is_completed)                                     AS completed_tasks,
        COUNTIF(NOT t.is_completed)                                 AS open_tasks,
        COUNTIF(NOT t.is_completed AND t.due_on < CURRENT_DATE())   AS overdue_tasks,
        COUNT(DISTINCT IF(NOT t.is_completed, t.assignee_id, NULL)) AS assignees_with_open_tasks,
        MAX(t.completed_at)                                         AS last_completed_at,
        MAX(t.modified_at)                                          AS last_task_modified_at
    FROM {{ ref('stg_asana__project_task') }} pt
    JOIN {{ ref('stg_asana__task') }} t USING (task_id)
    GROUP BY 1
)

SELECT
    p.project_id,
    p.project_name,
    p.workspace_id,
    p.team_id,
    tm.team_name,
    p.owner_id,
    o.user_name                                   AS owner_name,
    p.is_archived,
    p.current_status_color,
    p.created_at,
    p.due_date,
    DATE_DIFF(p.due_date, CURRENT_DATE(), DAY)    AS days_until_due,
    COALESCE(s.tasks, 0)                          AS tasks,
    COALESCE(s.completed_tasks, 0)                AS completed_tasks,
    COALESCE(s.open_tasks, 0)                     AS open_tasks,
    COALESCE(s.overdue_tasks, 0)                  AS overdue_tasks,
    SAFE_DIVIDE(s.completed_tasks, s.tasks)       AS pct_complete,
    COALESCE(s.assignees_with_open_tasks, 0)      AS assignees_with_open_tasks,
    s.last_completed_at,
    s.last_task_modified_at
FROM {{ ref('stg_asana__project') }} p
LEFT JOIN task_stats s USING (project_id)
LEFT JOIN {{ ref('stg_asana__team') }} tm ON tm.team_id = p.team_id
LEFT JOIN {{ ref('stg_asana__user') }} o ON o.user_id = p.owner_id
