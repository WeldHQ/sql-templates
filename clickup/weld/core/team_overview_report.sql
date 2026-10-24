-- core.clickup.team_overview_report
-- Team Overview Report. Generates a team overview report by retrieving data from
-- the ClickUp integration. It calculates the total number of tasks, total time
-- spent, task status, and task count for each team. The report includes team ID,
-- name, color, total tasks, total time spent, task status, and tasks in each
-- status. The results are ordered by team ID.
--
-- From the weld.app template library. Not reconciled against ClickUp;
-- check the output against the source before relying on it.

with
    TeamTasks as (
        select
            t.team_id
          , count(distinct t.id) as total_tasks
        from
            {{raw.clickup.task}} t
        group by
            t.team_id
    )
  , TeamTime as (
        select
            t.team_id
          , sum(time.duration) as total_time_spent
        from
            {{raw.clickup.time}} time
            join {{raw.clickup.task}} t on time.task_id = t.id
        group by
            t.team_id
    )
  , TeamTaskStatus as (
        select
            t.team_id
          , t.status_status as task_status
          , count(distinct t.id) as task_count
        from
            {{raw.clickup.task}} t
        group by
            t.team_id
          , t.status_status
    )
select
    team.id as team_id
  , team.name as team_name
  , team.color as team_color
  , coalesce(tt.total_tasks, 0) as total_tasks
  , coalesce(ttime.total_time_spent, 0) as total_time_spent
  , coalesce(tts.task_status, 'N/A') as task_status
  , coalesce(tts.task_count, 0) as tasks_in_status
from
    {{raw.clickup.team}} team
    left join TeamTasks tt on team.id = tt.team_id
    left join TeamTime ttime on team.id = ttime.team_id
    left join TeamTaskStatus tts on team.id = tts.team_id
order by
    team.id
