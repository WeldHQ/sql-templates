# Mailchimp templates

Rebuilds Mailchimp's campaign reports and audience dashboard in your warehouse: one row
per sent campaign, audience growth per day, and contact counts per audience. BigQuery.

Weld connector: **Mailchimp** ([docs](https://weld.app/docs/applications/mailchimp)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/campaign_performance.sql`](weld/core/campaign_performance.sql) · [dbt](dbt/models/core/core_mailchimp__campaign_performance.sql) | Campaign report (Reports > a campaign) | campaign |
| [`weld/core/audience_growth_daily.sql`](weld/core/audience_growth_daily.sql) · [dbt](dbt/models/core/core_mailchimp__audience_growth_daily.sql) | Audience analytics: growth and activity | day × audience |
| [`weld/core/audience_summary.sql`](weld/core/audience_summary.sql) · [dbt](dbt/models/core/core_mailchimp__audience_summary.sql) | Audience dashboard: contacts by status | audience (as of last sync) |

## Layers

```
raw.mailchimp.*         ELT output, untouched
  ↓
weld/staging/*.sql      9 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql         the reports
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Staging casts, renames and keeps the latest synced copy of each row. Core holds the
report logic. Analytics is a `SELECT *` over core, so dashboards bind to a name that does
not change when core does.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.mailchimp.campaign}}` expects the model in a
`staging > mailchimp` folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| campaign performance | `campaign`, `campaign_setting`, `campaign_recipient`, `campaign_report_summary`, `campaign_member_recipient`, `member_activity` |
| audience growth daily | `list_activity`, `list` |
| audience summary | `list`, `member` |

`campaign_setting`, `campaign_recipient` and `campaign_report_summary` are written by the
`campaign` stream; `campaign_member_recipient` and `member_activity` are their own streams.

## What campaign_performance returns

Mailchimp's own numbers, straight from the campaign report: `opens`, `unique_opens`,
`open_rate`, `clicks`, `unique_clickers`, `click_rate`, `ecommerce_orders`,
`ecommerce_revenue`. These match the UI. The two rates are fractions (0.42, not 42).

Rebuilt from the per-recipient "sent to" list: `recipients`, `hard_bounces`,
`soft_bounces` and `delivered`. Mailchimp computes its open and click rates over
successful deliveries, so `unique_opens / delivered` should land on `open_rate`. That is
the quickest check that the sent-to stream is complete.

`unsubscribes` is counted from the member activity feed. See the schema notes for why it
is a floor.

## Schema notes

- **Member activity is capped at 50 events per member.** That is how Mailchimp's member
  activity endpoint works, not a sync setting. Unsubscribes are a member's last action, so
  they are usually present, but very active members on older campaigns can lose theirs.
  Treat `unsubscribes` as a lower bound and compare with the campaign report.
- **Audience activity starts 180 days back.** Mailchimp serves the last 180 days of
  `list_activity`. Older days are only in the warehouse if the connector was already
  syncing then.
- **No per-campaign click URLs or opens by time.** The connector does not sync the click
  details or open details reports, so the link performance table and the hourly opens
  chart are not rebuilt.
- **Member ids repeat across audiences.** Mailchimp derives the member id from the email
  address, so every key here includes `list_id`.
- **Two scales for rates.** Campaign reports give rates as fractions; audience stats
  (`open_rate_pct`, `click_rate_pct`) give percentages. The column names say which.
- **E-commerce revenue** is in the connected store's currency and is only populated when a
  store is connected to the audience.
- Staging columns were checked against the published ERD and the connector's stream
  definitions; they agree for every table used here.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, open three recent
campaigns in Mailchimp's Reports and compare recipients, opens, clicks, bounces and
unsubscribes with `campaign_performance`. Then compare one audience's subscribed count on
the Audience dashboard with `audience_summary.subscribed_count` and `members_subscribed`.

[Mailchimp Marketing API: reports](https://mailchimp.com/developer/marketing/api/reports/) ·
[Audience activity](https://mailchimp.com/developer/marketing/api/list-activity/) ·
[About open and click rates](https://mailchimp.com/help/about-open-and-click-rates/)
