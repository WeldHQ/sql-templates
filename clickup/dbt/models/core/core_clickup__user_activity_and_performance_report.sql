-- core_clickup__user_activity_and_performance_report
-- User Activity and Performance Report. Generates a user activity and performance
-- report by integrating with ClickUp. It retrieves information such as the total
-- number of tasks, tasks completed, tasks overdue, total time spent, task priority,
-- task status, and task count by priority and status for each user. The results are
-- ordered by user ID.
--
-- From the weld.app template library. Not reconciled against ClickUp;
-- check the output against the source before relying on it.

with
    UserTasks as (
        select
            ta.id as user_id
          , ta.username
          , count(distinct t.id) as total_tasks
          , count(
                distinct case
                    when t.date_done is not null then t.id
                    else null
                end
            ) as tasks_completed
          , count(
                distinct case
                    when t.date_done is null
                    and cast(timestamp_millis(cast(t.due_date as int)) as date) < current_date then t.id
                    else null
                end
            ) as tasks_overdue
        from
            {{ source('clickup', 'task_assignees') }}ta
            join {{ source('clickup', 'task') }} t on ta.task_id = t.id
        group by
            ta.id
          , ta.username
    )
  , UserTime as (
        select
            user_id
          , sum(duration) as total_time_spent
        from
            {{ source('clickup', 'time') }}
        group by
            user_id
    )
  , UserTaskDetails as (
        select
            ta.id as user_id
          , t.priority
          , t.status_status
          , count(t.id) as task_count
        from
            {{ source('clickup', 'task_assignees') }} ta
            join {{ source('clickup', 'task') }} t on ta.task_id = t.id
        group by
            ta.id
          , t.priority
          , t.status_status
    )
select
    u.id as user_id
  , u.username
  , u.email
  , u.color
  , u.initials
  , u.last_active
  , ut.total_tasks
  , ut.tasks_completed
  , ut.tasks_overdue
  , utme.total_time_spent
  , utd.priority
  , utd.status_status
  , utd.task_count as tasks_by_priority_status
from
    {{ source('clickup', 'user') }} u
    left join UserTasks ut on u.id = ut.user_id
    left join UserTime utme on u.id = utme.user_id
    left join UserTaskDetails utd on u.id = utd.user_id
order by
    u.id
