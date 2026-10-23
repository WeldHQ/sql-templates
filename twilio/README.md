# Twilio templates

Rebuilds the overview numbers from Twilio's Messaging Insights and Voice Insights in your
warehouse: messages sent, delivered and failed, errors by code, calls answered, minutes
and spend. BigQuery.

Weld connector: **Twilio** ([docs](https://weld.app/docs/applications/twilio)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/messaging_daily.sql`](weld/core/messaging_daily.sql) · [dbt](dbt/models/core/core_twilio__messaging_daily.sql) | Messaging Insights: overview and delivery | day × account × messaging service × direction × currency |
| [`weld/core/message_errors_daily.sql`](weld/core/message_errors_daily.sql) · [dbt](dbt/models/core/core_twilio__message_errors_daily.sql) | Messaging Insights: errors | day × account × messaging service × error code |
| [`weld/core/calls_daily.sql`](weld/core/calls_daily.sql) · [dbt](dbt/models/core/core_twilio__calls_daily.sql) | Voice Insights / Call Logs summary | day × account × direction × currency |

## Layers

```
raw.twilio.*            ELT output, untouched
  ↓
weld/staging/*.sql      3 thin wrappers: cast, flip the price sign, de-duplicate
  ↓
weld/core/*.sql         the daily reports
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.twilio.message}}` expects the model in a `staging > twilio`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| messaging daily, message errors daily | `message`, `messaging_service` |
| calls daily | `call` |

## How the numbers are defined

- **Cost is positive.** Twilio reports each charge as a negative `price` in `price_unit`
  currency. Staging flips the sign once, so `cost` sums the way an invoice does. A message
  has no price until the carrier has priced it; `messages_not_yet_priced` counts those.
- **Delivery rate** is delivered (including `read`) over outbound messages in a final
  state: delivered, read, undelivered, failed. `sent` means the carrier never returned a
  receipt, which is normal on some routes; those messages are counted in
  `sent_no_receipt` and left out of the denominator.
- **Segments** are what SMS is billed on. A long or Unicode message is several segments.
- **Call legs.** A forwarded call is two billed legs, the parent and an `outbound-dial`
  child. `call_legs` and `cost` count both; `parent_calls` counts conversations.
- **Billable minutes** round each completed leg up to the minute. That matches how most
  voice usage is billed, but not SIP or per-second routes. Use `cost` for money.
- Every rate is per row. Sum the counts and divide again when you aggregate.

## Schema notes

- **Day is UTC.** Twilio timestamps are UTC; the Console shows them in your account's
  time zone, so single days near midnight can differ.
- **Usage records are not used.** Each usage record row covers one category over the
  range from a sync's start day to the day it ran. Consecutive rows share their
  boundary days, and a day's usage keeps changing until it
  is over, so the rows cannot be summed into a clean daily or monthly spend series. Spend
  here is built from message and call prices instead, which leaves out phone number
  rental, Verify, Conversations and other products billed outside messages and calls.
- **In-progress calls are absent.** A call arrives only after it ends.
- **Message bodies are not carried into staging.** None of the reports need content, and
  it is personal data.
- Staging columns were checked against the published ERD and the schema Weld syncs;
  they agree for every table used here.

## Notes

- Metric definitions were cross-checked against Fivetran's open-source `dbt_twilio`
  package; the SQL here is written independently for Weld's schema.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, compare a closed
month of `messaging_daily` (messages, segments, cost) and `calls_daily` (legs, minutes,
cost) with Twilio Console > Monitor > Insights and with the SMS and voice lines on that
month's usage invoice. Expect cost to match the SMS and voice lines, not the invoice
total.

[Messages API][messages] · [Message status values][statuses] · [Calls API][calls] ·
[Error and warning dictionary][errors]

[messages]: https://www.twilio.com/docs/messaging/api/message-resource
[statuses]: https://www.twilio.com/docs/messaging/api/message-resource#message-status-values
[calls]: https://www.twilio.com/docs/voice/api/call-resource
[errors]: https://www.twilio.com/docs/api/errors
