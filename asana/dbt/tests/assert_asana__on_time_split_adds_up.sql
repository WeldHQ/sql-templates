-- In task_completion, every completed task with a due date is either on time or
-- late, never both and never neither. Returns zero rows when that holds. A
-- failure means the due-time and due-date rules disagree on some task.

SELECT completed_date, project_id, assignee_id,
       tasks_with_due_date, completed_on_time, completed_late
FROM {{ ref('core_asana__task_completion') }}
WHERE completed_on_time + completed_late != tasks_with_due_date
