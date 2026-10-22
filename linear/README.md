# Linear templates

Four reports on engineering flow in Linear: what came in and what got done, how
long work takes, what is waiting, and how each cycle is going. BigQuery.

Weld connector: **Linear** ([docs](https://weld.app/docs/applications/linear)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/issue_flow.sql`](weld/core/issue_flow.sql) · [dbt](dbt/models/core/core_linear__issue_flow.sql) | Insights: issues created vs completed | day × team × assignee |
| [`weld/core/issue_cycle_time.sql`](weld/core/issue_cycle_time.sql) · [dbt](dbt/models/core/core_linear__issue_cycle_time.sql) | Insights: lead time, cycle time, triage time | completed issue |
| [`weld/core/open_backlog.sql`](weld/core/open_backlog.sql) · [dbt](dbt/models/core/core_linear__open_backlog.sql) | Insights: open issues by status and priority, with age | team × state × priority × assignee, current snapshot |
| [`weld/core/cycle_progress.sql`](weld/core/cycle_progress.sql) · [dbt](dbt/models/core/core_linear__cycle_progress.sql) | Cycle scope and completion | team × cycle |

## Layers

```
raw.linear.*           ELT output, untouched
  ↓
weld/staging/issue.sql one thin wrapper: cast ISO timestamps, drop trashed issues, keep the latest version
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

The `issues` stream already carries team, state, assignee, project and cycle
names, so the reports need no other table. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.linear.issue}}` expects the model in a `staging > linear` folder.

## Required tables

| Model | Raw tables |
|---|---|
| all four | `issues` |

## Schema notes

- **Current state only.** The connector syncs issues as they are now, not their
  state history. Every report uses an issue's current team, assignee and cycle.
  Cycle time is measured with Linear's own `startedAt` and `completedAt`
  timestamps, which Linear sets on entering a started or completed state, so it is
  accurate even without history.
- **Cycle scope is end-of-cycle scope.** Issues that rolled over to the next cycle
  count in the cycle they are in now. Linear's cycle graph, which uses history,
  shows a larger starting scope for finished cycles.
- **Cycle dates and label names are not synced.** Issues carry `label_ids` but
  there is no label table, so there is no "by label" breakdown. Cycles have no
  start or end date here.
- **Timestamps arrive as ISO strings** and are cast to `TIMESTAMP` in staging. All
  dates in the reports are UTC days; Linear shows days in your own time zone.
- **Archived issues are kept, trashed issues are dropped.** Linear auto-archives
  completed issues after a period, and the connector requests archived issues, so
  history stays intact. `open_backlog` excludes archived issues.
- The `comments`, `teams` and `users` tables are available but not needed here.

## Reconciling

Nothing here has been run against a live warehouse. Compare one team's completed
issue count for last month with a Linear filter (team, completed, last month), and
the median cycle time with Linear Insights for the same filter, before relying on
the output. Expect small differences at day boundaries because of time zones.

[Linear API](https://linear.app/developers/graphql) ·
[Insights](https://linear.app/docs/insights)
