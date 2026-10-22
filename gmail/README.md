# Gmail templates

Turns a synced Gmail mailbox into the reports people usually build by hand: email volume
per day, response times, and who the mailbox talks to. BigQuery.

Weld connector: **Gmail** ([docs](https://weld.app/docs/applications/gmail)).

Gmail has no built-in reporting, so there is no vendor report to recreate. These models
answer the questions a shared inbox or a sales mailbox gets asked: how much comes in, how
fast it is answered, and with whom.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/messages.sql`](weld/core/messages.sql) · [dbt](dbt/models/core/core_gmail__messages.sql) | One clean row per email, the base for the others | message |
| [`weld/core/email_volume_daily.sql`](weld/core/email_volume_daily.sql) · [dbt](dbt/models/core/core_gmail__email_volume_daily.sql) | How much is sent and received | day × direction |
| [`weld/core/response_times.sql`](weld/core/response_times.sql) · [dbt](dbt/models/core/core_gmail__response_times.sql) | How long received mail waits for a reply | received message that opens a wait |
| [`weld/core/correspondents_monthly.sql`](weld/core/correspondents_monthly.sql) · [dbt](dbt/models/core/core_gmail__correspondents_monthly.sql) | Who the mailbox talks to | month × address |

## Layers

```
raw.gmail.*             ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, de-duplicate, keep the message's own headers
  ↓
weld/core/*.sql         messages, then the three reports built on it
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

`core.gmail.messages` does the joining once: labels give direction, headers give sender,
recipients and subject. The three reports read only from it.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.gmail.message}}` expects the model in a `staging > gmail`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

`message`, `message_label`, `message_part_header` (all written by the `message` stream)
and `profile`.

## How it decides things

- **Sent or received** comes from Gmail's `SENT` label, which Gmail applies to anything
  sent from the account, from any client or alias. Drafts are excluded.
- **Time** is Gmail's `internalDate`: when Gmail received the message, or when it was sent.
  It is UTC. The `Date` header is ignored because the sender's client sets it.
- **Addresses** are extracted from the From, To and Cc headers with a regular expression,
  so display names drop away. `counterpart` is the sender of received mail and the first
  To address of sent mail.
- **A wait** in `response_times` opens with the first received message in a thread after
  the start or after your last reply, and closes with your next sent message in that
  thread. Follow-ups that arrive before you answer join the same wait. Times are wall
  clock, not business hours.

## Schema notes

- **Spam and Trash are not synced**, so they are not in any count.
- **Labels are a snapshot at sync time.** The message stream is incremental on message
  date, so archiving, reading or relabelling an older message is not picked up until it is
  synced again. `is_unread` and `is_in_inbox` describe the message when it was fetched,
  not today.
- **Automated mail is included.** Newsletters, receipts and notifications count as
  received mail and show up as unanswered waits. Gmail's own categories are on every row
  as `inbox_category` (primary, promotions, social, updates, forums); filter to `primary`
  for mail from people.
- **Root headers only.** Headers are read from the message's root MIME part, the one with
  an empty part id. Attachment and alternative-body headers are ignored.
- Staging columns were checked against the published ERD and the connector's stream
  definitions; they agree for every table used here.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, pick a day and search
Gmail for `after:YYYY/MM/DD before:YYYY/MM/DD` and `in:sent` with the same range, and
compare the counts with `email_volume_daily` (Gmail's search uses your account time zone,
these models use UTC, so pick a quiet day or convert). Then open three threads from
`response_times` and check the reply times by eye.

[Gmail API: messages](https://developers.google.com/gmail/api/reference/rest/v1/users.messages) ·
[System labels](https://developers.google.com/gmail/api/guides/labels)
