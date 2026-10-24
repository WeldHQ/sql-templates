# Calendly templates

Meeting volume, cancellations, no-shows and booking sources from Weld's Calendly
connector. BigQuery.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/scheduled_events.sql`](weld/core/scheduled_events.sql) · [dbt](dbt/models/core/core_calendly__scheduled_events.sql) | Every meeting, its outcome, hosts and lead time | scheduled event |
| [`weld/core/meetings_by_day.sql`](weld/core/meetings_by_day.sql) · [dbt](dbt/models/core/core_calendly__meetings_by_day.sql) | Calendly's "Scheduled events" analytics: booked, held, canceled, no-show | day × host × event type |
| [`weld/core/bookings_by_source.sql`](weld/core/bookings_by_source.sql) · [dbt](dbt/models/core/core_calendly__bookings_by_source.sql) | Which UTM sources book meetings that actually happen | booking month × UTM source × medium × campaign × event type |

## Read this first: what this connector cannot do

**1. There is no event type table.** The connector syncs scheduled events and
invitees, not the list of event types. Each meeting carries its event type's URI
and a `name`, which is the event type's name at the time of booking. The models
key on the URI and label it with the most recent name it was booked under. An event
type nobody has booked does not exist as far as these models know, and duration,
slug or active/inactive flags of an event type are not available.

**2. Invitee cancellation detail is not synced.** Calendly attaches a cancellation
object (who, when, why) to each invitee; the connector syncs it on the scheduled
event only. For one-on-one meetings that is the same thing. For a group event,
which invitee canceled and why is not recoverable.

**3. No-shows are whatever your hosts marked.** Calendly only knows an invitee did
not show if the host clicked "Mark as no-show". `completed` in these models means
"not canceled and not marked as a no-show", not "attended". If your team does not
mark no-shows, the no-show rate is zero and means nothing.

**4. Routing forms are a link, not a table.** An invitee carries the URI of the
routing form submission that sent them, so `bookings_via_routing_form` can be
counted. The routing form questions and answers are not synced.

## Layers

```
raw.calendly.*          ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, dedupe, unpack JSON
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts the ISO timestamp strings, unpacks the JSON objects (location,
invitee counter, cancellation, UTM tracking, no-show, payment, the host list) and
dedupes. The dedupe matters: scheduled events are synced once per organisation
member, so a meeting with two hosts lands twice in raw.

**Core** holds the outcome classification, the reschedule chain and the date
spine. `scheduled_events` is meeting grain and the other two read it.

**Analytics** exists for indirection, not transformation. Bind dashboards to
`analytics.calendly.meetings_by_day` so core stays free to change. All three are
`SELECT *` on purpose.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.calendly.invitee}}` expects the model in a `staging > calendly`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| scheduled events | `list_events`, `list_event_invitees` |
| meetings by day | the same, plus `list_organization_memberships` |
| bookings by source | `list_events`, `list_event_invitees` |

`list_user_availability_schedules` and `list_activity_log_entries` are synced but
not modelled. Availability rules are configuration, not activity, and the activity
log is an Enterprise-plan audit trail with a free-form `details` payload.

## What scheduled_events returns

One row per meeting. `outcome` is one of `upcoming`, `completed`, `no_show`,
`canceled` or `rescheduled`:

- **rescheduled** is a canceled meeting whose every canceled invitee has
  `rescheduled = TRUE`. Calendly implements a reschedule as cancel plus rebook, and
  its own analytics does not count these as cancellations. Neither do these models.
- **no_show** is a past, active meeting where every invitee was marked a no-show. A
  group meeting where only some did not show stays `completed`, with the count in
  `no_show_invitees`.

Also on the row: `booking_lead_time_hours` (first booking to meeting start),
`duration_minutes`, `location_type`, `host_count` / `host_names`, invitee counts by
status, `new_bookings` (invitees that are not the second half of a reschedule) and
the cancellation's `canceler_type` (`host` or `invitee`) and `cancel_reason`.

## Notes

- **meetings_by_day has two date axes, named apart.** `booked_meetings` lands on
  the booking date; every other measure lands on the meeting date. Calendly's
  analytics page has the same toggle.
- **Hosts fan out on purpose.** A collective meeting with three hosts is one meeting
  in each host's row. Sum `org_meetings_scheduled` for organisation totals; it
  counts each meeting once.
- **bookings_by_source follows reschedules.** It starts from each original booking,
  walks the reschedule chain to the last invitee and takes the outcome from there,
  so a meeting moved twice is one booking, not three. Source, month and event type
  stay those of the original booking.
- **`show_rate` excludes upcoming bookings** from the denominator, so the current
  month is not dragged down by meetings that have not happened yet.
- **Days are cut in UTC.** Calendly returns UTC; change the `'UTC'` literal in
  `meetings_by_day` and `bookings_by_source` to your reporting zone.
- **Deletes are full refreshes.** The connector re-reads every stream in full on each
  sync, so a meeting deleted in Calendly disappears from raw on the next sync.
- **Multi-account ready.** Every staging model emits a `calendly_account` label and
  it is part of every join key. To add an organisation, `UNION ALL` a second block in
  each staging model with a different label, and change nothing else.
- **Not run against a warehouse.** These models were checked for syntax and schema,
  not executed. Reconcile a month of `meetings_by_day` against Calendly's Analytics
  page (created, completed, rescheduled and canceled events) before relying on the output.

[Calendly connector docs](https://weld.app/docs/applications/calendly) ·
[Calendly API: scheduled events](https://developer.calendly.com/api-docs/2d5ed9bbd2952-list-events) ·
[Calendly API: invitees](https://developer.calendly.com/api-docs/eb8ee72701f99-list-event-invitees) ·
[Calendly analytics](https://calendly.com/help/calendly-analytics)
