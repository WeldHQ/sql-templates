-- core.clickup.task_dependency_analysis
-- Task Dependency Analysis. Performs a task dependency analysis in ClickUp. It
-- retrieves information about task dependencies, including task names, statuses,
-- and dependent task details. It also calculates the total number of dependencies
-- for each task and determines if a task is a potential blocker based on its status
-- and the status of its dependent tasks. The results are sorted by task ID and
-- dependent task ID.
--
-- From the weld.app template library. Not reconciled against ClickUp;
-- check the output against the source before relying on it.

with
    TaskDependencies as (
        select
            td.task_id
          , t.name as task_name
          , t.status_status as task_status
          , td.depends_on as dependent_task_id
          , dt.name as dependent_task_name
          , dt.status_status as dependent_task_status
        from
            {{raw.clickup.task_dependencies}} td
            join {{raw.clickup.task}} t on td.task_id = t.id
            left join {{raw.clickup.task}} dt on td.depends_on = dt.id
    )
  , DependencyCounts as (
        select
            task_id
          , count(dependent_task_id) as total_dependencies
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
        when td.task_status = 'Completed'
        and td.dependent_task_status != 'Completed' then 'Potential Blocker'
        else 'No Blocker'
    end as blocker_status
  , dc.total_dependencies
from
    TaskDependencies td
    join DependencyCounts dc on td.task_id = dc.task_id
order by
    td.task_id
  , td.dependent_task_id
