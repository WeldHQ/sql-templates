# Gorgias templates

Ticket volume and open backlog, first response and resolution times with medians,
one-touch rates, satisfaction, agent performance and Gorgias Voice calls, from
Weld's Gorgias connector. BigQuery.

Weld connector: **Gorgias** ([docs](https://weld.app/docs/applications/gorgias)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/ticket_lifecycle.sql`](weld/core/ticket_lifecycle.sql) · [dbt](dbt/models/core/core_gorgias__ticket_lifecycle.sql) | Every ticket with team, channel, assignee, derived first response and resolution, message counts, survey score | ticket |
| [`weld/core/ticket_volume_by_day.sql`](weld/core/ticket_volume_by_day.sql) · [dbt](dbt/models/core/core_gorgias__ticket_volume_by_day.sql) | Created, closed and open backlog over time | day × team × channel |
| [`weld/core/response_times_by_month.sql`](weld/core/response_times_by_month.sql) · [dbt](dbt/models/core/core_gorgias__response_times_by_month.sql) | First response and resolution time (mean, median), messages per ticket, one-touch, satisfaction | created month × team × channel |
| [`weld/core/agent_performance_by_month.sql`](weld/core/agent_performance_by_month.sql) · [dbt](dbt/models/core/core_gorgias__agent_performance_by_month.sql) | Closed tickets, first responses, messages and satisfaction per agent | month × agent |
| [`weld/core/voice_calls_by_day.sql`](weld/core/voice_calls_by_day.sql) · [dbt](dbt/models/core/core_gorgias__voice_calls_by_day.sql) | Calls, answered, voicemail and talk time | day × direction × status |

Every grain also includes `gorgias_account`.

## Read this first

**Response and resolution times are derived, not copied.** Gorgias computes its
statistics internally and the ticket object carries none of them, so the models
rebuild them from the message log and the close timestamp, in calendar minutes:

- **First response**: from the customer's first message to the first public
  message sent from the helpdesk that was not sent by a rule. Messages written by
  AI Agent or an app through the API look like agent messages on the synced data
  and are counted; `first_response_via` shows how each reply was sent if you want
  to filter some out. Gorgias also offers a "human first response time" for this
  reason, and the two will differ on accounts that use AI Agent heavily.
- **Resolution**: from ticket creation to the latest close.

**Only the latest close is known.** Gorgias overwrites `closed_datetime` when a
reopened ticket is closed again. Closed counts here are tickets by latest close;
Gorgias' "Tickets closed" counts every close. If that difference matters, enable
the `ticket-closed` event type in the connector settings, which syncs every close
event into an `event_ticket_closed` table. It is optional and not used here.

**The historical backlog is a reconstruction.** It is running created minus running
closed, each ticket in the team and channel it has now, so a reopened ticket is
open from creation to its last close. The last day ties exactly to today's open
count. Snoozed tickets are open in Gorgias and are counted as open here.

**Statistics reports are not used.** The connector can also sync reports you define
yourself from Gorgias' statistics API (`report_*` tables). Their tables and columns
depend on the scope, measures and dimensions you pick, so no template can rely on
them. They are a good cross-check: a `first-response-time` or `tickets-closed`
report synced next to these models lets you reconcile Gorgias' own numbers against
the derived ones.

**Time zone.** Timestamps are UTC and the account time zone is not synced. Set
`reporting_timezone` in `weld/staging/ticket.sql` to your IANA zone.

## Layers

```
raw.gorgias.*           ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, rename, unpack JSON, keep latest row
  ↓
weld/core/*.sql         the reports: all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps one row per id. It unpacks the assigned team
from its JSON object and the message sender's id and name, and reads the merged
flag across every copy of a ticket, because the connector receives merges as
separate events.

**Core** holds the first-response rule, the exclusions, the spine and the
aggregations. `ticket_lifecycle` is ticket grain and three of the other models read
it. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. All five are `SELECT *`.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.gorgias.ticket}}` expects the model in a `staging > gorgias`
folder.

## Required tables

| Model | Raw tables |
|---|---|
| ticket lifecycle | `ticket`, `ticket_message`, `satisfaction_survey` |
| ticket volume by day | the same |
| response times by month | the same |
| agent performance by month | the same |
| voice calls by day | `voice_call`, `ticket` (for the time zone) |

`voice_call` is only filled for accounts that use Gorgias Voice. The ticket models
run without it.

## What the reports return

**`ticket_lifecycle`** drops spam, trashed and merged tickets, as Gorgias'
statistics do. It flags `is_outbound` (the helpdesk wrote first), `is_one_touch`
(closed after one agent message) and `is_zero_touch` (closed with none), and counts
agent, rule, customer and internal-note messages separately.

**`response_times_by_month`** is dated on ticket creation, which is how Gorgias
dates first response and resolution time. The latest months therefore keep filling
in as tickets are answered and closed. Satisfaction uses Gorgias' 1 to 5 score:
`average_survey_score`, `satisfaction_rate` (share scored 4 or 5) and
`survey_response_rate` (answered over sent).

**`agent_performance_by_month`** dates each block on its own event: closed tickets
on the close month and to the current assignee, first responses and messages on
their send month and to the sender.

**`voice_calls_by_day`** keeps `status` as a dimension. Gorgias documents
`status` and `termination_status` as free strings without publishing the full list
of values, so grouping them into missed or abandoned is left to you once you have
seen what your account produces. A call counts as answered when Gorgias recorded an
agent or forwarding number answering it.

## Reconciling against Gorgias

Nothing here has been run against a live warehouse. Before relying on it:

1. Today's total `open_backlog_end_of_day` should equal the open ticket count in
   Gorgias; [`assert_backlog_ties_to_open`](dbt/tests/assert_backlog_ties_to_open.sql)
   checks the model side.
2. For a closed month, compare tickets created and the median first response time
   with Statistics → Support performance, filtered to the same channels. A gap on
   first response usually comes from AI Agent or API replies (filter on
   `first_response_via`).
3. Compare closed tickets with Gorgias, remembering that Gorgias counts every close.

## Schema notes

- The public ERD types timestamp columns (`created_datetime`, `closed_datetime`, ...)
  as `date`. The connector loads them as millisecond timestamps; staging casts to
  `TIMESTAMP`.
- `assignee_team` and the message `sender` are JSON objects stored as strings.

## Notes

- **Medians do not roll up.** Rebuild means from the `_sum_` and count columns;
  query `ticket_lifecycle` for a median at another grain.
- **Multi-account ready.** Every staging model emits a `gorgias_account` label and
  it is part of every join key and grain. To add an account, `UNION ALL` a second
  block in each staging model with a different label.

Vendor references:
[Gorgias API reference](https://developers.gorgias.com/reference) ·
[Voice call object](https://developers.gorgias.com/reference/the-voicecall-object)
