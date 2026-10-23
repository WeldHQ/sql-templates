# Mixpanel templates

Rebuilds the core Mixpanel Insights and Funnels numbers in your warehouse: events and
unique users per event per day, DAU/WAU/MAU with stickiness and new users, sessions,
and your saved funnels step by step. BigQuery.

Weld connector: **Mixpanel** ([docs](https://weld.app/docs/applications/mixpanel)).
The integration id, and so the folder and namespace, is `mixpanel-source`.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/events_daily.sql`](weld/core/events_daily.sql) · [dbt](dbt/models/core/core_mixpanel_source__events_daily.sql) | Insights: total events and unique users, by event | day × event name |
| [`weld/core/active_users_daily.sql`](weld/core/active_users_daily.sql) · [dbt](dbt/models/core/core_mixpanel_source__active_users_daily.sql) | Insights: DAU, WAU, MAU and stickiness | day |
| [`weld/core/sessions.sql`](weld/core/sessions.sql) · [dbt](dbt/models/core/core_mixpanel_source__sessions.sql) | Session counts and lengths (30-minute timeout) | session |
| [`weld/core/funnel_conversion_daily.sql`](weld/core/funnel_conversion_daily.sql) · [dbt](dbt/models/core/core_mixpanel_source__funnel_conversion_daily.sql) | Funnels: your saved funnels | funnel × entry day × step |

## Layers

```
raw.mixpanel_source.*   ELT output, untouched
  ↓
weld/staging/*.sql      2 thin wrappers: de-duplicate events, unpack funnel steps
  ↓
weld/core/*.sql         the reports
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.mixpanel_source.events}}` expects the model in a
`staging > mixpanel_source` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| events daily, active users daily, sessions | `events` |
| funnel conversion daily | `funnels` |

## Two kinds of numbers

The event models count raw events, so you can slice them any way you like. The funnel
model reads results Mixpanel computed for your saved funnels, so it matches the Funnels
report exactly but only for funnels you have saved, and only as they are defined in
Mixpanel.

Why the event counts can differ slightly from Mixpanel's UI:

- **Identity.** Mixpanel merges an anonymous device and the user it later logs in as into
  one person. These models count the raw `distinct_id`, so unique users can run a little
  higher than Mixpanel shows.
- **Time zone.** Days here are UTC. Mixpanel shows days in your project time zone.
- **Sessions.** Mixpanel computes sessions at query time and does not export them.
  `sessions` rebuilds them with Mixpanel's default 30-minute inactivity timeout and splits
  them at UTC midnight. If your project uses a different timeout or event-based sessions,
  adjust the model before comparing.
- **Rolling windows.** WAU and MAU use 7- and 28-day windows ending on the row's day,
  Mixpanel's defaults. The first 27 days of synced history have incomplete windows, flagged
  by `is_full_window`.

## Schema notes

- **The events table is as wide as your tracking plan.** There is one column per event
  property, snake_cased, so no two projects have the same table. These models read the
  columns that are always present (`event_hash`, `event_name`, `distinct_id`, `time`)
  plus `insert_id`. Add your own properties in staging to report
  on them.
- **ERD versus warehouse.** The published ERD for this connector lists only `event_hash`
  and `event_name` on `events`, because the rest of the table is project-specific. The
  table always also has `distinct_id` and `time` (event time in seconds), and these
  models rely on both. `insert_id` is Mixpanel's `$insert_id`
  property, snake_cased; it is present whenever your SDKs send it, which the official
  ones do.
- **Duplicates are removed by Mixpanel's own rule.** Mixpanel shows one copy of events
  that share name, `distinct_id`, time and `$insert_id`. A client retry produces such a
  copy with different processing metadata, so `event_hash` (a hash of the whole
  event) differs between them and would count both. Staging de-duplicates on the
  four fields instead, falling back to `event_hash` for events without an insert id. If
  your table has no `insert_id` column, set it to NULL in staging.
- **Funnel days restate.** Each funnel day is a cohort of users entering on that day, and
  Mixpanel updates it until the conversion window has passed. Staging keeps the latest
  copy of each funnel day.
- **Not used:** `revenue` (Mixpanel's legacy Revenue report, built on people-profile
  transactions), `people`, `cohorts`, `cohort_members` and `annotations`. They are synced,
  but none of the three reports needs them.

## Notes

- Metric definitions were cross-checked against Fivetran's open-source `dbt_mixpanel`
  package; the SQL here is written independently for Weld's schema.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, open Mixpanel
Insights for one event over a closed week, set the chart to UTC if you can or pick
mid-week days, and compare totals and uniques with `events_daily`. Then open one saved
funnel for a range that ended longer ago than its conversion window and compare with
`funnel_conversion_daily`.

[Raw event export](https://docs.mixpanel.com/reference/raw-event-export) ·
[Funnels query API](https://docs.mixpanel.com/reference/funnels-query) ·
[Identity management](https://docs.mixpanel.com/docs/tracking-methods/id-management)
