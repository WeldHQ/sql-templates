# Zendesk templates

Rebuilds the core of Zendesk Explore's Support dashboard in your warehouse: ticket
volume and backlog, first reply and resolution times with medians, and CSAT, by
group, channel and agent. BigQuery.

Weld connector: **Zendesk** ([docs](https://weld.app/docs/applications/zendesk)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/ticket_lifecycle.sql`](weld/core/ticket_lifecycle.sql) · [dbt](dbt/models/core/core_zendesk__ticket_lifecycle.sql) | Every ticket with its dimensions, Zendesk's time metrics and CSAT | ticket |
| [`weld/core/ticket_volume_by_day.sql`](weld/core/ticket_volume_by_day.sql) · [dbt](dbt/models/core/core_zendesk__ticket_volume_by_day.sql) | Created, solved and unsolved backlog over time ("Tickets" tab) | day × group × channel |
| [`weld/core/response_times_by_month.sql`](weld/core/response_times_by_month.sql) · [dbt](dbt/models/core/core_zendesk__response_times_by_month.sql) | First reply, full resolution, requester wait (mean and median), one-touch, CSAT ("Efficiency" and "Satisfaction" tabs) | solve month × group × channel |
| [`weld/core/agent_performance_by_month.sql`](weld/core/agent_performance_by_month.sql) · [dbt](dbt/models/core/core_zendesk__agent_performance_by_month.sql) | Solved tickets, reply and resolution times and CSAT per agent | solve month × assignee |

Every grain also includes `zendesk_account`.

## Read this first: what this connector can and cannot do

**The time metrics are Zendesk's own.** The connector syncs `ticket_metric`
alongside every ticket, so first reply time, first and full resolution time,
requester wait, agent wait and on-hold time come straight from Zendesk, in
minutes, both in calendar time and in business hours. Nothing is recomputed from
comments, and the numbers should match Explore once you filter and date them the
same way. Pick calendar or business per report and stay with it: mixing the two is
the most common reason a warehouse figure disagrees with Explore.

**There is no ticket history.** The connector syncs each ticket as it is now. Two
consequences:

- **Only the latest solve is known.** `ticket_metric.solved_at` is overwritten
  when a reopened ticket is solved again. Solved counts here are tickets by latest
  solve date; Explore's "Solved tickets" counts solve events, so a ticket solved
  twice counts twice there and once here. `reopens` tells you how often it happens.
- **The historical backlog is a reconstruction.** `ticket_volume_by_day` computes
  it as running created minus running solved, with each ticket in the group and
  channel it has today. The last day ties exactly to the current unsolved count;
  earlier days are an approximation. If an exact backlog history matters,
  materialise that model on a daily schedule and keep the runs.

`ticket_audit` is also synced and holds status changes as a JSON array. It does
not include archived tickets, so it cannot give a complete history either and is
not used here.

**CSAT has no date of its own.** The satisfaction rating on a ticket is a score
(`good`, `bad`, `offered`, `unoffered`) and a reason, with no timestamp, so CSAT is
dated on the ticket's solve date. Explore dates it on the rating update, which can
move a late rating into the next month.

**Time zone.** Timestamps are UTC and the connector does not sync the account's
time zone. Set `reporting_timezone` in `weld/staging/ticket.sql` to your account's
zone (an IANA name such as `Europe/Copenhagen`) or every late-evening ticket lands
on the wrong day.

## Layers

```
raw.zendesk.*           ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, rename, unpack JSON, keep latest row
  ↓
weld/core/*.sql         the reports: all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and de-duplicates. The ticket stream reads Zendesk's
incremental export, which Zendesk documents as able to return a ticket more than
once, so staging keeps the latest version of each ticket and each metric row. It
also pulls `channel` out of the `via` JSON and the score out of
`satisfaction_rating`.

**Core** holds the solved/unsolved classification, the spine and the aggregations.
`ticket_lifecycle` is ticket grain and the other three read it. This is the layer
worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.zendesk.*` so core stays free to be renamed or
re-grained. All four are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.zendesk.ticket}}` expects the model in a `staging > zendesk`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ticket lifecycle | `ticket`, `ticket_metric`, `group`, `user` |
| ticket volume by day | the same |
| response times by month | the same |
| agent performance by month | the same |

`ticket_metric` is not a stream of its own: it is filled when the `ticket` stream
syncs. `group` and `user` only supply names; without them every report still runs
but groups and agents show as IDs.

## What the reports return

**`ticket_lifecycle`**: status with `is_solved` / `is_unsolved` (Zendesk's
definition: `new`, `open`, `pending` and `hold` are unsolved), `channel` (from
`via.channel`: `email`, `web`, `chat`, `voice`, `api`, `native_messaging` and so
on), group, assignee, priority, type, `created_date` and `resolved_date` in your
reporting time zone, every `ticket_metric` duration, `replies`, `reopens`,
`is_one_touch`, `is_two_touch` and `is_multi_touch` (solved with one, two, or
three or more public agent replies), `solve_count` (derived from `reopens`) and
the CSAT flags. Deleted tickets are dropped, as in Explore.

**`ticket_volume_by_day`**: `tickets_created`, `tickets_solved` and
`unsolved_backlog_end_of_day`. Built on a day spine, so a quiet group or channel
returns zeros instead of a gap. Sum across groups and channels freely; every
column is additive.

**`response_times_by_month`** and **`agent_performance_by_month`**: the tickets
solved in each month, with mean and median of each duration and CSAT as
`good / (good + bad)`. Means can be rebuilt at any level from the `_sum_` and count
columns. **Medians cannot be rolled up**: the median for a whole month is not the
average of the group medians. For a median at another grain, query
`ticket_lifecycle`. Medians use `APPROX_QUANTILES`, which is approximate on very
large inputs.

## Reconciling against Zendesk

Nothing here has been run against a live warehouse. Before relying on it:

1. Compare today's total of `unsolved_backlog_end_of_day` with the "Unsolved
   tickets" count in Zendesk. They should match exactly;
   [`assert_zendesk__backlog_ties_to_unsolved`](dbt/tests/assert_zendesk__backlog_ties_to_unsolved.sql)
   checks it.
2. In Explore, build "Tickets solved" and "First reply time (min), median" by
   month on *Ticket solved, Date* and compare with `response_times_by_month`.
   Differences of a few tickets usually come from reopened tickets (see above) or
   the reporting time zone.
3. Compare CSAT for a closed month. A gap usually means late ratings.

## Schema notes

- The public ERD types every Zendesk timestamp column (`created_at`, `solved_at`
  and the like) as `date`. They arrive as millisecond timestamps.
  Staging casts them to `TIMESTAMP`, which is correct either way.
- `via` and `satisfaction_rating` are JSON objects stored as strings.
- **No schedules or holidays.** The connector does not sync Zendesk's business
  hour schedules, holidays or the schedule assigned to each ticket, so business
  time cannot be recomputed here. The `_business` columns are Zendesk's own
  figures and are used as they are. A custom business-hours metric (for example,
  time to the second reply in business hours) cannot be built.
- **No SLA policies.** SLA policies and their per-ticket targets are not synced,
  so SLA breach reports cannot be built from this connector.
- **No complete field history.** A daily history of each ticket's status,
  assignee, group or priority needs every change event. The `ticket_audit`
  table has them as a JSON array, but it leaves out archived tickets (Zendesk
  archives tickets closed for more than 120 days). A history built on it would silently lose older tickets, so
  none is built. This is also why solved counts use the latest solve.

## Notes

- **Agent attribution is the current assignee.** The connector syncs no
  assignment history and Zendesk's reply metric does not say who replied.
- **Multi-account ready.** Every staging model emits a `zendesk_account` label and
  it is part of every join key and grain. To add an account, `UNION ALL` a second
  block in each staging model with a different label and change nothing else.
  Ticket IDs are only unique within one account.
- **Business hours come from Zendesk.** The `_business` columns use the schedule
  Zendesk applied to each ticket; there is no need to model your hours.
- **Touch counts use Zendesk's reply count.** `replies` counts public agent
  replies, so a ticket answered only with private notes is in no touch bucket.
  Compare with Explore's "One-touch tickets" for a closed month before relying
  on the rate.
- Metric definitions were cross-checked against Fivetran's open-source
  `dbt_zendesk` package; the SQL here is written independently for Weld's schema.

Vendor references:
[Ticket metrics API](https://developer.zendesk.com/api-reference/ticketing/tickets/ticket_metrics/) ·
[Incremental exports](https://developer.zendesk.com/api-reference/ticketing/ticket-management/incremental_exports/)
