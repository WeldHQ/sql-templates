# SendGrid templates

Rebuilds SendGrid's Stats pages in your warehouse: the delivery funnel per day, per
category and per mailbox provider, plus the suppression lists as a daily series.
BigQuery.

Weld connector: **SendGrid**.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/email_stats_daily.sql`](weld/core/email_stats_daily.sql) · [dbt](dbt/models/core/core_sendgrid__email_stats_daily.sql) | Stats > Overview | day |
| [`weld/core/category_stats_daily.sql`](weld/core/category_stats_daily.sql) · [dbt](dbt/models/core/core_sendgrid__category_stats_daily.sql) | Stats > Categories | day × category |
| [`weld/core/mailbox_provider_stats_daily.sql`](weld/core/mailbox_provider_stats_daily.sql) · [dbt](dbt/models/core/core_sendgrid__mailbox_provider_stats_daily.sql) | Stats > Mailbox Providers | day × mailbox provider |
| [`weld/core/suppressions_daily.sql`](weld/core/suppressions_daily.sql) · [dbt](dbt/models/core/core_sendgrid__suppressions_daily.sql) | Suppressions (Bounces, Blocks, Invalid Emails, Spam Reports, Global Unsubscribes) | day × suppression type |

## Layers

```
raw.sendgrid.*          ELT output, untouched
  ↓
weld/staging/*.sql      8 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql         the reports: funnel, rates, suppression series
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Staging casts, renames and keeps the latest synced copy of each row. Core holds the
funnel and the rate definitions. Analytics is a `SELECT *` over core, so dashboards can
bind to a name that does not change when core does.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.sendgrid.stat}}` expects the model in a
`staging > sendgrid` folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| email stats daily | `stat` |
| category stats daily | `legacy_category_stat` |
| mailbox provider stats daily | `mailbox_provider_stat` |
| suppressions daily | `bounce`, `block`, `invalid_email`, `spam_report`, `global_unsubscribe` |

## How the numbers are defined

SendGrid's funnel: `requests` is what you asked it to send, `processed` is what it
accepted (requests minus drops), `delivered` is what the receiving server accepted.
`bounces`, `blocks` and `deferred` are permanent rejections, reputation or policy
rejections, and delays that are retried. The `*_drops` columns are messages never
attempted because the address was already suppressed.

Rates use SendGrid's own denominators: delivery and bounce rates over `requests`,
open, click, spam-report and unsubscribe rates over `delivered`. Per-provider stats have
no `requests`, so there the denominator is `delivered + bounces + blocks`.

Every rate is per row. To report a week or a month, sum the counts and divide again.
`unique_opens` and `unique_clicks` are unique within a day as SendGrid reports them, so
they cannot be summed into a unique count for a longer window.

## Schema notes

- **Statistics are daily aggregates, not events.** SendGrid's Stats API is the source,
  so there is no per-message or per-recipient grain here. The `message` table (the Email
  Activity Feed) needs SendGrid's paid Email Activity History add-on, and the connector
  reads one page of up to 1,000 messages per sync, so it is not complete enough to
  report on and is not used.
- **No per-campaign stats.** The connector syncs Single Sends (`single_send`) as objects
  without their statistics. Per-campaign reporting works through categories: give each
  campaign a category when sending and use `category_stats_daily`.
- **Categories do not sum to the account.** A message with several categories is
  counted under each; a message with none is in no category row.
- **Suppressions are a history, not today's list.** Removing an address in SendGrid
  removes it from the list, but rows already synced stay in the warehouse.
- **Dates are the day buckets SendGrid's Stats API returns.** If the SendGrid UI shows
  a different time zone, days near midnight can land on different dates. Unless you set
  a start date on the connection, the stats streams fetch the last year on first sync.
- Staging columns were checked against the published ERD and the connector's stream
  definitions; they agree for every table used here.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, pick a closed month
and compare `email_stats_daily` summed over the month with SendGrid's Stats > Overview for
the same range, then one category with Stats > Categories. Opens move for a few days after
a send, so compare a month that ended at least a week ago.

[SendGrid Stats API](https://www.twilio.com/docs/sendgrid/api-reference/stats) ·
[Metrics definitions](https://www.twilio.com/docs/sendgrid/ui/analytics-and-reporting/stats-overview) ·
[Suppressions](https://www.twilio.com/docs/sendgrid/ui/sending-email/index-suppressions)
