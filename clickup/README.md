# ClickUp templates

SQL reports over Weld's ClickUp connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/monthly_time_tracking_and_billing_report.sql`](weld/core/monthly_time_tracking_and_billing_report.sql) · [dbt](dbt/models/core/core_clickup__monthly_time_tracking_and_billing_report.sql) | Monthly Time Tracking and Billing Report | Generates a monthly time tracking and billing report using data from ClickUp. It calculates the billable and non-billable time for each user, as well as the total time spent. The report also includes the billable amount, calculated based on a hypothetical rate of $50 per hour. |
| [`weld/core/task_checklist_progress.sql`](weld/core/task_checklist_progress.sql) · [dbt](dbt/models/core/core_clickup__task_checklist_progress.sql) | Task Checklist Progress | Generates a report on the progress of task checklists in ClickUp. It retrieves the total number of checklist items, resolved items, and unresolved items for each task. It calculates the completion percentage based on the resolved items and total checklist items. The results are sorted by completion percentage and task ID. |
| [`weld/core/task_dependency_analysis.sql`](weld/core/task_dependency_analysis.sql) · [dbt](dbt/models/core/core_clickup__task_dependency_analysis.sql) | Task Dependency Analysis | Performs a task dependency analysis in ClickUp. It retrieves information about task dependencies, including task names, statuses, and dependent task details. It also calculates the total number of dependencies for each task and determines if a task is a potential blocker based on its status and the status of its dependent tasks. The results are sorted by task ID and dependent task ID. |
| [`weld/core/team_overview_report.sql`](weld/core/team_overview_report.sql) · [dbt](dbt/models/core/core_clickup__team_overview_report.sql) | Team Overview Report | Generates a team overview report by retrieving data from the ClickUp integration. It calculates the total number of tasks, total time spent, task status, and task count for each team. The report includes team ID, name, color, total tasks, total time spent, task status, and tasks in each status. The results are ordered by team ID. |
| [`weld/core/user_activity_and_performance_report.sql`](weld/core/user_activity_and_performance_report.sql) · [dbt](dbt/models/core/core_clickup__user_activity_and_performance_report.sql) | User Activity and Performance Report | Generates a user activity and performance report by integrating with ClickUp. It retrieves information such as the total number of tasks, tasks completed, tasks overdue, total time spent, task priority, task status, and task count by priority and status for each user. The results are ordered by user ID. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Corrected in review:

- `core/monthly_time_tracking_and_billing_report` converts ClickUp's millisecond durations to hours (`*_hours` columns) and computes `billable_amount` from billable hours. Running timers, which carry a negative duration, are left out.
- `core/task_dependency_analysis` flags a dependency as a potential blocker when the waiting task is still open and the task it waits on is not finished. The website version flagged completed tasks instead. Finished is read from the status type (closed or done), so custom status names work, and a dependency on a task that is not synced shows as Unknown.

## Required tables

| Model | Raw tables |
|---|---|
| `core/monthly_time_tracking_and_billing_report` | `clickup.time` |
| `core/task_checklist_progress` | `clickup.task_checklists`, `clickup.task` |
| `core/task_dependency_analysis` | `clickup.task_dependencies`, `clickup.task` |
| `core/team_overview_report` | `clickup.task`, `clickup.team`, `clickup.time` |
| `core/user_activity_and_performance_report` | `clickup.task_assignees`, `clickup.task`, `clickup.time`, `clickup.user` |

## Models

### Monthly Time Tracking and Billing Report

`weld/core/monthly_time_tracking_and_billing_report.sql`

The Monthly Time Tracking and Billing Report SQL template is designed to generate a
summary of time tracking and billing data on a monthly basis. This template
integrates with ClickUp, a project management tool, to extract relevant data.

### Task Checklist Progress

`weld/core/task_checklist_progress.sql`

The SQL template "Task Checklist Progress" is designed to analyze the progress of
task checklists in ClickUp. It retrieves data from the "task_checklists" table in
the ClickUp integration and calculates various metrics related to checklist items.

### Task Dependency Analysis

`weld/core/task_dependency_analysis.sql`

The SQL template named "Task Dependency Analysis" is designed to analyze task
dependencies in the ClickUp integration. This SQL model retrieves information about
task dependencies, including the task ID, task name, task status, dependent task ID,
dependent task name, dependent task status, and the total number of dependencies for
each task.

### Team Overview Report

`weld/core/team_overview_report.sql`

The SQL template "Team Overview Report" is designed to provide a comprehensive
overview of team performance using data from the ClickUp integration. This SQL model
combines information from multiple tables to generate insights about team tasks,
time spent, and task status.

### User Activity and Performance Report

`weld/core/user_activity_and_performance_report.sql`

The SQL template "User Activity and Performance Report" is designed to gather data
from the ClickUp integration. It provides insights into user activity and
performance based on various metrics.
