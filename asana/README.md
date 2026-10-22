# Asana templates

Three reports on delivery in Asana: what got done and whether it was on time, who
is carrying what right now, and how each project is tracking. BigQuery.

Weld connector: **Asana** ([docs](https://weld.app/docs/applications/asana)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/task_completion.sql`](weld/core/task_completion.sql) · [dbt](dbt/models/core/core_asana__task_completion.sql) | Throughput, on-time rate, days to complete | completion date × project × assignee |
| [`weld/core/open_task_workload.sql`](weld/core/open_task_workload.sql) · [dbt](dbt/models/core/core_asana__open_task_workload.sql) | Open, overdue and due-soon work per person (Asana's Workload view, as a table) | assignee × project, current snapshot |
| [`weld/core/project_overview.sql`](weld/core/project_overview.sql) · [dbt](dbt/models/core/core_asana__project_overview.sql) | Status colour, progress and overdue tasks per project (a portfolio overview) | project, current snapshot |

## Layers

```
raw.asana.*            ELT output, untouched
  ↓
weld/staging/*.sql     6 thin wrappers: cast, rename, keep the latest version of each task
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` over core so dashboards can bind to a stable name.
`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.asana.task}}` expects the model in a `staging > asana` folder.

## Required tables

| Model | Raw tables |
|---|---|
| task completion | `task`, `project_task`, `project`, `user`, `story` |
| open task workload | `task`, `project_task`, `project`, `user` |
| project overview | `task`, `project_task`, `project`, `team`, `user` |

## Schema notes

- **Unassigned tasks are not synced.** The connector lists tasks once per user,
  filtered on that user as assignee. Every count here is a count of *assigned*
  tasks, so project progress can differ from Asana's own progress bar, which
  includes unassigned ones.
- **A reassigned task leaves a stale row.** The raw `task` table is keyed on task,
  workspace and assignee, so after a reassignment the old assignee's row stays.
  `staging.asana.task` keeps the most recently modified version of each task,
  which holds the current assignee.
- **Tasks have no `created_at`.** The connector does not request it. Time to
  complete is measured from the task's earliest story (the "created this task"
  event in practice), which needs the `story` stream.
- **No sections or custom fields.** Board columns and custom field values are not
  synced, so there is no "tasks by section" or "by priority" report.
- **Project status colour is current only.** `project.current_status_color` is the
  latest status; status history lives in `project_status`, which carries the text
  and title of each update but not its colour.
- The `goal`, `goal_status` and `workspace` tables are available but not used.

## Notes

- **Multi-homed tasks count once per project.** Asana lets a task live in several
  projects. Per-project numbers are right; summing projects double-counts.
- **Dates are UTC.** `completed_date` is the UTC date of `completed_at`. `due_on`
  is the calendar date Asana stores, with no time zone.
- **Ratios are carried as numerator and denominator.** Re-aggregate
  `avg_days_to_complete` as `SUM(days_to_complete_total) / SUM(tasks_with_known_start)`
  and `on_time_rate` as `SUM(completed_on_time) / SUM(tasks_with_due_date)`.

## Reconciling

Nothing here has been run against a live warehouse. Compare a project's completed
task count for last month with an Asana search ("Completed on" last month, in that
project), and one person's open tasks with their Asana workload view, before relying
on the output.

[Asana API: tasks](https://developers.asana.com/reference/tasks) ·
[stories](https://developers.asana.com/reference/stories)
