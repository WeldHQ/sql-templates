# Freshdesk templates

Ticket volume, first response time with medians and SLA attainment, agent activity
and CSAT from Weld's Freshdesk connector, by group, channel and agent. BigQuery.

Weld connector: **Freshdesk** ([docs](https://weld.app/docs/applications/freshdesk)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/ticket_lifecycle.sql`](weld/core/ticket_lifecycle.sql) · [dbt](dbt/models/core/core_freshdesk__ticket_lifecycle.sql) | Every ticket with decoded status, channel, group, assignee, derived first response and latest CSAT | ticket |
| [`weld/core/ticket_volume_by_day.sql`](weld/core/ticket_volume_by_day.sql) · [dbt](dbt/models/core/core_freshdesk__ticket_volume_by_day.sql) | Created, first responded, replies in and out | day × group × channel |
| [`weld/core/first_response_by_month.sql`](weld/core/first_response_by_month.sql) · [dbt](dbt/models/core/core_freshdesk__first_response_by_month.sql) | First response time (mean, median, p90) and first-response SLA rate | created month × group × channel |
| [`weld/core/agent_performance_by_month.sql`](weld/core/agent_performance_by_month.sql) · [dbt](dbt/models/core/core_freshdesk__agent_performance_by_month.sql) | Replies, first responses and their speed, assigned tickets, CSAT per agent | month × agent |
| [`weld/core/csat_by_month.sql`](weld/core/csat_by_month.sql) · [dbt](dbt/models/core/core_freshdesk__csat_by_month.sql) | Satisfaction survey results | response month × group × agent |

Every grain also includes `freshdesk_account`.

## Read this first: what this connector cannot do

**There is no resolution time.** Freshdesk keeps `resolved_at`, `closed_at` and
`first_responded_at` in a separate "stats" block on each ticket, which is not part
of the synced data. That has three consequences:

- **Resolution time and "resolved per day" cannot be built.** `updated_at` is not a
  substitute: it moves on every later edit, and Freshdesk's own auto-close of
  resolved tickets moves it again days later. `is_resolved` tells you whether a
  ticket is resolved now, which is all the data supports.
- **There is no backlog history.** `unresolved_now` in `ticket_volume_by_day` is a
  snapshot of today's state, grouped by creation day. If a backlog trend matters,
  materialise `ticket_lifecycle` daily and keep the runs.
- **First response time is derived.** It is computed from the conversation log:
  the first public, non-automated reply written by an agent, minus the ticket's
  creation time, in calendar minutes. Freshdesk's report can also show business
  hours; that needs the stats block, so calendar time is all that is available.
  Expect small differences from Freshdesk's own number where its rules differ
  (for example on tickets forwarded in or replied to by a public note).

**Deleted and spam tickets go stale.** Freshdesk's ticket list hides deleted and
spam tickets, so a ticket deleted or marked spam after it was
synced therefore stops updating and keeps its last state in the warehouse. If the
counts must match Freshdesk exactly, run a full resync of the `ticket` stream from
time to time.

**Time zone.** Timestamps are UTC. The synced `account` table holds the helpdesk
time zone as a display name ("Eastern Time (US & Canada)") that BigQuery cannot
use, so set `reporting_timezone` in `weld/staging/ticket.sql` to the IANA name
(`America/New_York`).

## Layers

```
raw.freshdesk.*         ELT output, untouched
  ↓
weld/staging/*.sql      5 thin wrappers: cast, rename, decode integer codes, keep latest row
  ↓
weld/core/*.sql         the reports: all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and decodes Freshdesk's integer codes for status,
priority and source, so core never repeats the mapping. Unknown codes are kept as
`status_7` and the like rather than turned into NULL: custom statuses show up by
number until you name them in `weld/staging/ticket.sql`. `satisfaction_rating`
attaches the answer to the survey's default question.

**Core** holds the first-response rule, the spine and the aggregations.
`ticket_lifecycle` is ticket grain and the other models read it. This is the layer
worth reviewing.

**Analytics** exists for indirection, not transformation. All five are `SELECT *`.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.freshdesk.ticket}}` expects the model in a
`staging > freshdesk` folder.

## Required tables

| Model | Raw tables |
|---|---|
| ticket lifecycle | `ticket`, `ticket_conversation`, `agent`, `group`, `satisfaction_rating`, `satisfaction_rating_value` |
| ticket volume by day | the same |
| first response by month | the same |
| agent performance by month | the same |
| csat by month | `satisfaction_rating`, `satisfaction_rating_value`, `agent`, `group`, `ticket` (for the time zone) |

**Sync `agent` even if you do not need agent reports.** It is how a reply is
recognised as an agent's reply. Without it there is no first response time at all.

## How first response is defined

The earliest conversation on the ticket that is written by a user in `agent`, not
incoming, not private, not a note (`source = 2`), and not an automated response.
Outbound email tickets (`source = 10`, an agent wrote first) are flagged
`is_outbound` and left out of response-time figures. The ticket's own first
message is its description, which is not a conversation, so a ticket nobody has
replied to has no conversation rows.

`is_first_response_within_sla` compares that reply with `fr_due_by`, the target
Freshdesk set on the ticket from its SLA policy, so the business-hours logic of the
policy is already inside the due date.

## CSAT

Freshdesk stores each answer as a number around 100: 100 is neutral, values above
100 are positive (103 is the happiest) and negative values are unhappy. The exact
values depend on the survey's point scale, so the models classify by comparison
with 100 rather than by a fixed list. `csat_score` is positive answers over all
answers to the default question, neutral included. Ratings carry their own agent and
group, so `csat_by_month` attributes them to whoever handled the ticket at survey
time, dated on the answer.

## Reconciling against Freshdesk

Nothing here has been run against a live warehouse. Before relying on it, compare a
closed month of tickets created by group with Freshdesk's Helpdesk In-depth report,
the median first response time for that month (switch the report to calendar
hours), and the CSAT score in the Satisfaction survey report.

## Schema notes

- The public ERD types timestamp columns (`created_at`, `fr_due_by`, ...) as `date`.
  They arrive as millisecond timestamps; staging casts to `TIMESTAMP`.
- Custom ticket fields land as extra `cf_*` columns that differ per helpdesk. They
  are not used here; add the ones you report on to `weld/staging/ticket.sql`.
- `satisfaction_rating_value.survey_question_id` holds Freshdesk's question key,
  which is `default_question` for the main CSAT question.

## Notes

- **Medians do not roll up.** Monthly medians are per row; sum the `_sum_` and count
  columns for a mean at any level, or query `ticket_lifecycle` for another median.
- **Columns in `agent_performance_by_month` are dated on different events.** Replies
  on the reply date, assignments on the ticket's creation date, CSAT on the answer
  date. Do not divide one by another.
- **Multi-helpdesk ready.** Every staging model emits a `freshdesk_account` label
  and it is part of every join key. To add a helpdesk, `UNION ALL` a second block in
  each staging model with a different label.

Vendor references: [Freshdesk API v2](https://developers.freshdesk.com/api/)
