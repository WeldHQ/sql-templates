-- core_asana__open_task_workload
-- Current open workload per assignee and project: what is open, overdue and due
-- soon. A snapshot as of the last sync, not a history.
-- Grain: assignee x project.
--
-- "Overdue" follows Asana: a task with a due time (due_at) is overdue once that
-- moment has passed, a task with only a due date once that date is over. Both
-- are compared with the current UTC time. A task in two
-- projects appears under both; `open_tasks` per assignee summed across projects
-- double-counts those tasks.

SELECT
    t.assignee_id,
    u.user_name                                              AS assignee_name,
    u.email                                                  AS assignee_email,
    pt.project_id,
    p.project_name,
    COUNT(*)                                                 AS open_tasks,
    COUNTIF(t.parent_task_id IS NOT NULL)                    AS open_subtasks,
    COUNTIF(IF(t.due_at IS NOT NULL, t.due_at < CURRENT_TIMESTAMP(), t.due_on < CURRENT_DATE()))
                                                             AS overdue_tasks,
    COUNTIF(t.due_on BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), INTERVAL 6 DAY)) AS due_next_7_days,
    COUNTIF(t.due_on IS NULL)                                AS without_due_date,
    MIN(t.due_on)                                            AS earliest_due_on,
    MAX(IF(t.due_on < CURRENT_DATE(), DATE_DIFF(CURRENT_DATE(), t.due_on, DAY), NULL)) AS max_days_overdue
FROM {{ ref('stg_asana__task') }} t
LEFT JOIN {{ ref('stg_asana__project_task') }} pt USING (task_id)
LEFT JOIN {{ ref('stg_asana__project') }} p ON p.project_id = pt.project_id
LEFT JOIN {{ ref('stg_asana__user') }} u ON u.user_id = t.assignee_id
WHERE NOT t.is_completed
  AND COALESCE(p.is_archived, FALSE) = FALSE
GROUP BY 1, 2, 3, 4, 5
