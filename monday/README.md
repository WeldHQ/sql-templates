# monday.com templates

Three reports on how work moves through your monday.com boards: what happened on
each board, how long items sit in each status, and who is assigned to what.
BigQuery.

Weld connector: **monday.com** ([docs](https://weld.app/docs/applications/monday.com)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/board_activity.sql`](weld/core/board_activity.sql) · [dbt](dbt/models/core/core_monday__board_activity.sql) | What happened on each board, by whom (monday's Activity Log, counted) | day (UTC) × board × user × event |
| [`weld/core/status_changes.sql`](weld/core/status_changes.sql) · [dbt](dbt/models/core/core_monday__status_changes.sql) | Status transitions and time in each status (cycle time) | one row per status change |
| [`weld/core/item_assignments.sql`](weld/core/item_assignments.sql) · [dbt](dbt/models/core/core_monday__item_assignments.sql) | Workload: items per person across boards | item × people column × person |

## Layers

```
raw.monday.*           ELT output, untouched
  ↓
weld/staging/*.sql     5 thin wrappers: cast, rename, de-duplicate, parse JSON
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` over core so dashboards can bind to a stable name
while core changes. `dbt/` holds the same models with dbt refs, generated from the
Weld versions; see [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths: `{{staging.monday.item}}` expects the model in a
`staging > monday` folder.

## Required tables

| Model | Raw tables |
|---|---|
| board activity | `activity_logs`, `board`, `user` |
| status changes | `activity_logs`, `board`, `item`, `user` |
| item assignments | `item`, `item_column_values`, `board`, `user` |

## Schema notes

What is synced decides what can be built, so it is worth knowing:

- **Status labels exist only in the activity log.** An item's status column value
  is stored as JSON holding the label *index*, and board column settings (which map
  index to label text) are not synced. `status_changes` therefore reads label text
  from `update_column_value` events. An item whose status has not changed inside
  the log window has no row there, and its current label is unknown.
- **Activity log retention depends on your monday plan.** monday only returns log
  history for a limited period, so `board_activity` and `status_changes` start
  where that window starts. Weld keeps what it has synced, so history builds up
  from the day you connect.
- **Archived and deleted items are not synced.** The `item` table holds what a
  board's items page returns today. Counts of items per board will not match a
  board view that includes archived items.
- **Groups and column titles are not synced.** Items carry no group, and columns
  are identified by their id (`status`, `person`, `date4`). `status_changes` picks
  up the column title from the log payload.
- **`item_column_values.id` is the column id, not a row id.** It repeats across
  items, so staging keys that table on `item_id` + `column_id`.
- **`activity_logs.created_at` is in units of 100 nanoseconds.** Staging divides
  by 10 and reads it as microseconds since the epoch.
- `item.account_id` exists on the table but is always empty, so it is not used.

## What it does not do

- No due-date or overdue report. Date columns are stored per board under arbitrary
  ids, so "the due date" means a different column on every board. Read
  `staging.monday.item_column_value` where `column_type = 'date'` and pick the
  column ids that mean due date in your account.
- No status distribution for items that never changed status in the log window, for
  the reason above.

## Reconciling

Nothing here has been run against a live warehouse. Before relying on it:

- Pick one board and one day and compare `board_activity` against the board's
  Activity Log in monday, filtered to that day. Days are UTC here, while monday
  shows your own time zone.
- Pick a handful of items and compare the latest `to_label` in `status_changes`
  with what the board shows.
- Compare `item_assignments` for one person with monday's "My work" view, keeping
  in mind that archived items are excluded here.

monday.com API docs: [activity logs](https://developer.monday.com/api-reference/reference/activity-logs) ·
[column values](https://developer.monday.com/api-reference/reference/column-values-v2)
