-- core.clickup.task_dependency_analysis
-- Task Dependency Analysis. Performs a task dependency analysis in ClickUp. It
-- retrieves information about task dependencies, including task names, statuses,
-- and dependent task details. It also calculates the total number of dependencies
-- for each task and flags dependencies that are still holding a task up. The
-- results are sorted by task ID and dependent task ID.
--
-- Grain: task x task it depends on. In ClickUp's dependency list, task_id is
-- waiting on depends_on. A dependency is a potential blocker while the waiting
-- task is still open and the task it waits on is not finished. Finished means
-- a status of type closed or done, so custom status names work too.
-- If the task waited on is not in the synced task table (deleted, or in a
-- space that is not synced), its status is unknown and the row says so.
--
-- From the weld.app template library, corrected. Not reconciled against
-- ClickUp; check the output against the source before relying on it.

with
    TaskDependencies as (
        select
            td.task_id
          , t.name as task_name
          , t.status_status as task_status
          , coalesce(t.status_type in ('closed', 'done'), false) as task_finished
          , td.depends_on as dependent_task_id
          , dt.id is not null as dependent_task_found
          , dt.name as dependent_task_name
          , dt.status_status as dependent_task_status
          , coalesce(dt.status_type in ('closed', 'done'), false) as dependent_task_finished
        from
            {{raw.clickup.task_dependencies}} td
            join {{raw.clickup.task}} t on td.task_id = t.id
            left join {{raw.clickup.task}} dt on td.depends_on = dt.id
    )
  , DependencyCounts as (
        select
            task_id
          , count(distinct dependent_task_id) as total_dependencies
        from
            TaskDependencies
        group by
            task_id
    )
select
    td.task_id
  , td.task_name
  , td.task_status
  , td.dependent_task_id
  , td.dependent_task_name
  , td.dependent_task_status
  , case
        when td.task_finished then 'No Blocker'
        when not td.dependent_task_found then 'Unknown'
        when not td.dependent_task_finished then 'Potential Blocker'
        else 'No Blocker'
    end as blocker_status
  , dc.total_dependencies
from
    TaskDependencies td
    join DependencyCounts dc on td.task_id = dc.task_id
order by
    td.task_id
  , td.dependent_task_id
