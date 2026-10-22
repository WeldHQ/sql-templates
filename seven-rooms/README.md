# SevenRooms templates

Covers, no-shows and spend per service, how far ahead guests book, and guest
feedback scores, for restaurants and venues on SevenRooms. BigQuery.

Weld connector: **SevenRooms** ([docs](https://weld.app/docs/applications/sevenrooms)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/covers_by_day.sql`](weld/core/covers_by_day.sql) · [dbt](dbt/models/core/core_seven_rooms__covers_by_day.sql) | Covers booked and arrived, cancellations, no-show rate, spend per cover | reservation date × venue × shift category |
| [`weld/core/booking_lead_time.sql`](weld/core/booking_lead_time.sql) · [dbt](dbt/models/core/core_seven_rooms__booking_lead_time.sql) | Booking pace by channel and reservation type | reservation date × venue × booked by × reservation type × lead time band |
| [`weld/core/guest_feedback.sql`](weld/core/guest_feedback.sql) · [dbt](dbt/models/core/core_seven_rooms__guest_feedback.sql) | Overall, food, drinks, service and ambience scores | reservation date × venue × feedback type |

## Layers

```
raw.seven_rooms.*      ELT output, untouched
  ↓
weld/staging/*.sql     3 thin wrappers: cast, rename, drop deleted reservations, fold statuses
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.seven_rooms.reservation}}` expects the model in a `staging > seven_rooms`
folder.

## Required tables

| Model | Raw tables |
|---|---|
| covers by day | `reservation`, `venue` |
| booking lead time | `reservation` |
| guest feedback | `reservation_feedback` |

## Schema notes

- **Statuses are folded into three outcomes** in `staging.seven_rooms.reservation`:
  canceled, no-show, and booked for everything else. SevenRooms has many
  statuses, venues can add their own, and the API does not publish the full list.
  Staging matches on both `status` and `status_simple`, ignoring case, spaces and
  hyphens. Look at the distinct values in your data and extend the `CASE` if a
  custom status should count as a cancellation or no-show.
- **Deleted reservations are dropped**; canceled ones are kept and counted.
- **Spend is what SevenRooms knows.** `net_spend` and `gross_spend` come from
  prepayments and on-site payments, including POS checks if a POS integration is
  connected. Without one, spend per cover will look low.
- **Reservation dates are venue days.** SevenRooms stores the reservation date
  without a time zone and it is used as is.
- **Feedback without a reservation** (for example on an online order) is stored
  with reservation id `unknown`.
- The `client`, `client_venue_stats`, `charge`, `event`, `program` and
  `reservation_request` tables are available but not used. `client` holds guest
  contact details; restrict access to it in your warehouse.

## Reconciling

Nothing here has been run against a live warehouse. Compare one venue and one
night of `covers_by_day` with the SevenRooms reservation book or covers report for
the same shift, and check that the canceled and no-show counts match.

[SevenRooms API](https://api-docs.sevenrooms.com/)
