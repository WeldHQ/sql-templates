# Iterable templates

Rebuilds Iterable's email campaign analytics in your warehouse from the raw message
events: sends, opens, clicks, bounces, complaints and unsubscribes, per campaign and per
day. BigQuery.

Weld connector: **Iterable** ([docs](https://weld.app/docs/applications/iterable)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/email_campaign_performance.sql`](weld/core/email_campaign_performance.sql) · [dbt](dbt/models/core/core_iterable__email_campaign_performance.sql) | Campaign Analytics: email metrics per campaign | campaign |
| [`weld/core/email_performance_daily.sql`](weld/core/email_performance_daily.sql) · [dbt](dbt/models/core/core_iterable__email_performance_daily.sql) | Campaign Analytics over time | day × campaign |

Email only. Push, SMS, in-app and web push have their own event tables in the connector
(`push_send`, `sms_send`, `in_app_open` and so on) and can be added the same way.

## Layers

```
raw.iterable.*          ELT output, untouched
  ↓
weld/staging/*.sql      7 thin wrappers: cast, rename, parse timestamps
  ↓
weld/core/*.sql         the reports
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.iterable.email_send}}` expects the model in a
`staging > iterable` folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

`campaigns`, `email_send`, `email_open`, `email_click`, `email_bounce`,
`email_complaint`, `email_unsubscribe`.

## How the numbers are defined

- **Delivered** is sends minus bounces.
- **Unique opens, clicks and unsubscribes** count distinct people (by email) per
  campaign, the way Iterable counts uniques. A triggered campaign that sends one person
  ten messages counts that person once. The unsubscribe rate uses unique unsubscribes.
- **Rates** are over delivered, except click-to-open, which is unique clicks over unique
  opens. Iterable's open rates include machine opens, such as Apple Mail Privacy
  Protection pre-fetching, so treat clicks as the firmer signal.
- **Campaign versus day.** `email_campaign_performance` attributes every event to its
  campaign whenever it happened. `email_performance_daily` puts each event on its own day,
  so a Monday send opened on Tuesday is a Monday send and a Tuesday open.

## Schema notes

- **The column names come from Iterable's export, not a fixed schema.** The connector
  writes each event's fields snake_cased (`campaignId` becomes `campaign_id`), with types
  inferred from your data, and there is no published ERD for this connector. These
  models read only fields Iterable includes on every email event: `campaign_id`,
  `template_id`, `message_id`, `email` and `created_at`. Run the staging models once and
  adjust any name that differs in your warehouse.
- **Timestamps are parsed defensively.** `created_at` can land as a timestamp, as
  Iterable's `2026-01-31 12:00:00 +00:00` text or as epoch milliseconds; staging handles
  all three. Times are UTC.
- **Event tables are re-read in full.** The connector exports each event type's whole
  history on every sync and replaces the table, so rows do not repeat. On a large project
  that makes syncs slow; that is a connector property, not something these models change.
- **Use `email_unsubscribe`, not `email_subscribe`.** In the current connector both tables
  are filled from Iterable's unsubscribe export, so `email_subscribe` holds unsubscribes.
- **`campaign_analytics_stream` holds user profiles, not campaign metrics.** The
  connector fills it from Iterable's user export, which is why the metrics here are rebuilt
  from the event tables instead.
- **Recurring campaigns and journeys are not rolled up.** Each run of a recurring blast is
  its own campaign id in Iterable, and journey sends carry their own campaign ids. The
  parent recurring campaign and the journey (workflow) id are only in the raw campaigns
  table when Iterable returns them, so these models report each campaign id on its own.
- **No user or list history.** The connector syncs the current user profiles, not a
  history of profile or list membership changes, so list growth over time and a user's
  state at the time of a send cannot be rebuilt.
- **Bot opens are not filtered.** Iterable's "filtered" open and click metrics drop
  events it flags as bots. That flag is not part of the fields these models rely on, so
  opens and clicks here match Iterable's unfiltered metrics.
- **Transactional sends without a campaign** are kept in the daily model under a NULL
  campaign and left out of the campaign table.

## Notes

- Metric definitions were cross-checked against Fivetran's open-source `dbt_iterable`
  package; the SQL here is written independently for Weld's schema.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, pick three blast
campaigns that finished sending more than a week ago and compare sends, unique opens,
unique clicks, bounces and unsubscribes with Iterable's Campaign Analytics.

[Iterable API documentation: export](https://api.iterable.com/api/docs#export_exportDataJson)
