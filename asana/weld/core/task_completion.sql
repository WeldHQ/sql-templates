-- core.asana.task_completion
-- Tasks completed per day, project and assignee, with on-time rate and time to
-- complete.
-- Grain: completion date (UTC) x project x assignee.
--
-- A task in two projects counts once in each project, so summing across projects
-- double-counts multi-homed tasks. Tasks in no project land under project_id NULL.
-- Subtasks are counted like any task; `subtasks_completed` shows how many of the
-- total they are.
--
-- On time means done by the due time when the task has one (due_at), and by the
-- end of the due date otherwise. The date comparison uses the UTC completion
-- date, so a task closed late in the evening west of UTC can read one day late.
--
-- Asana's task stream has no created_at. `days_to_complete` measures from the
-- task's earliest story (its "created this task" event in practice) to
-- completion, and only for tasks whose stories are synced. Average it as
-- SUM(days_to_complete_total) / SUM(tasks_with_known_start), never as an average
-- of averages.

WITH first_story AS (
    SELECT task_id, MIN(created_at) AS first_story_at
    FROM {{staging.asana.story}}
    GROUP BY 1
),

completed AS (
    SELECT
        t.task_id,
        t.assignee_id,
        t.parent_task_id IS NOT NULL                    AS is_subtask,
        DATE(t.completed_at)                            AS completed_date,
        t.due_on,
        CASE
            WHEN t.due_at IS NOT NULL THEN t.completed_at > t.due_at
            WHEN t.due_on IS NOT NULL THEN DATE(t.completed_at) > t.due_on
        END                                             AS is_late,
        TIMESTAMP_DIFF(t.completed_at, f.first_story_at, HOUR) / 24 AS days_to_complete
    FROM {{staging.asana.task}} t
    LEFT JOIN first_story f USING (task_id)
    WHERE t.is_completed
      AND t.completed_at IS NOT NULL
)

SELECT
    c.completed_date,
    pt.project_id,
    p.project_name,
    c.assignee_id,
    u.user_name                                             AS assignee_name,
    COUNT(*)                                                AS tasks_completed,
    COUNTIF(c.is_subtask)                                   AS subtasks_completed,
    COUNTIF(c.due_on IS NOT NULL)                           AS tasks_with_due_date,
    COUNTIF(NOT c.is_late)                                  AS completed_on_time,
    COUNTIF(c.is_late)                                      AS completed_late,
    SAFE_DIVIDE(COUNTIF(NOT c.is_late), COUNTIF(c.due_on IS NOT NULL)) AS on_time_rate,
    COUNTIF(c.days_to_complete IS NOT NULL)                 AS tasks_with_known_start,
    ROUND(SUM(c.days_to_complete), 2)                       AS days_to_complete_total,
    ROUND(SAFE_DIVIDE(SUM(c.days_to_complete), COUNTIF(c.days_to_complete IS NOT NULL)), 2) AS avg_days_to_complete
FROM completed c
LEFT JOIN {{staging.asana.project_task}} pt USING (task_id)
LEFT JOIN {{staging.asana.project}} p ON p.project_id = pt.project_id
LEFT JOIN {{staging.asana.user}} u ON u.user_id = c.assignee_id
GROUP BY 1, 2, 3, 4, 5
