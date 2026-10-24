-- core.clickup.task_checklist_progress
-- Task Checklist Progress. Generates a report on the progress of task checklists in
-- ClickUp. It retrieves the total number of checklist items, resolved items, and
-- unresolved items for each task. It calculates the completion percentage based on
-- the resolved items and total checklist items. The results are sorted by
-- completion percentage and task ID.
--
-- From the weld.app template library. Not reconciled against ClickUp;
-- check the output against the source before relying on it.

with
    TaskChecklistSummary as (
        select
            task_id
          , count(*) as total_checklist_items
          , sum(resolved) as resolved_items
          , sum(unresolved) as unresolved_items
        from
            {{raw.clickup.task_checklists}}
        group by
            task_id
    )
select
    t.id as task_id
  , t.name as task_name
  , coalesce(c.total_checklist_items, 0) as total_checklist_items
  , coalesce(c.resolved_items, 0) as resolved_items
  , coalesce(c.unresolved_items, 0) as unresolved_items
  , case
        when coalesce(c.total_checklist_items, 0) = 0 then 0
        else round(
            (coalesce(c.resolved_items, 0) * 100.0) / c.total_checklist_items
          , 2
        )
    end as completion_percentage
from
    {{raw.clickup.task}} t
    left join TaskChecklistSummary c on t.id = c.task_id
order by
    completion_percentage desc
  , task_id
