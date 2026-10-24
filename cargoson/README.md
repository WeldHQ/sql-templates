# Cargoson templates

Shipment volume, freight spend and carrier performance from Weld's Cargoson
connector. BigQuery, in each booking's own freight currency.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/shipments.sql`](weld/core/shipments.sql) · [dbt](dbt/models/core/core_cargoson__shipments.sql) | Every shipment with lane, carrier, agreed price, weight and transit | booking |
| [`weld/core/carrier_costs_by_month.sql`](weld/core/carrier_costs_by_month.sql) · [dbt](dbt/models/core/core_cargoson__carrier_costs_by_month.sql) | Freight spend, cost per kg and on-time rate per carrier and service over time | month × carrier × service × currency |
| [`weld/core/lane_costs.sql`](weld/core/lane_costs.sql) · [dbt](dbt/models/core/core_cargoson__lane_costs.sql) | What each country-to-country lane costs, by carrier | lane × carrier × freight type × currency |

## Read this first: what this connector can and cannot tell you

**1. You only get the bookings you list.** Cargoson's API has no "list all
bookings" endpoint, so Weld syncs each booking by reference from a table of
references you keep in your own warehouse (see the
[connector docs](https://weld.app/docs/applications/cargoson#syncing-bookings)).
Every number here covers exactly the bookings in that table. If it is fed from your
order system and misses manual bookings, so do these reports. Compare the shipment
count for a month against Cargoson's own shipment list before trusting any total.

**2. The price is the agreed price, not the invoice.** `freight_price` is the total
price of the offer the booking was made on. Waiting time, extra stops, fuel
adjustments and anything else the carrier invoices afterwards are not in it.
These models show what you agreed to pay; reconcile against carrier invoices for
what you actually paid.

**3. Weight is in kilograms only for metric bookings.** Cargoson documents a line's
`weight` as the total kilograms for the line. A booking made with
`measurement_units = 'imperial'` is kept with its raw figure in
`total_weight_as_entered`, but `weight_kg` is NULL for it, because Cargoson does not
document the imperial units and a guessed conversion would quietly distort cost per
kg.

**4. On-time is measured against the carrier's own estimate.** `is_on_time`
compares `delivered_at` with the estimated delivery date on the booked offer. When
either is missing it is NULL, not FALSE, and `on_time_rate` divides only by the
shipments where it could be judged. Carriers that do not report delivery events back
to Cargoson will show few judged shipments; read the denominator next to the rate.

## Layers

```
raw.cargoson.*          ELT output, untouched
  ↓
weld/staging/*.sql      2 thin wrappers: cast, rename, price string to number
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and normalises. The price arrives as a string and is
`SAFE_CAST` to a number; the declared goods value arrives in cents and is divided by
100.

**Core** holds the status classification, the goods-line aggregation, the month
spine and the rates. `shipments` is booking grain and the other two read it. This is
the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.cargoson.shipments` so core stays free to be renamed
or re-grained. All three are `SELECT *`: that is the point, not an oversight.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.cargoson.booking}}` expects the model in a `staging > cargoson`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| shipments | `bookings`, `booking_rows` |
| carrier costs by month | the same |
| lane costs | the same |

`booking_rows` lands automatically with `bookings`: it is the goods lines nested in
each booking. The other synced tables are deliberately not modelled:
`booking_row_adr_rows`, `booking_containers` and `booking_package_units` are detail
for dangerous goods, sea containers and SSCC labels that no cost report needs, and
`services` and `parcel_machines` are reference lists whose useful columns (carrier
and service name) are already on every booking.

## What shipments returns

One row per booking. `shipment_status` is `delivered`, `in_transit`, `open` or
`cancelled`, read from `latest_status` (which carries the transport milestones) and
falling back to `status` (the booking workflow). `is_cancelled` and `is_delivered`
sit alongside it.

`freight_cost` is the agreed price for every shipment that was not cancelled; sum
that column, not `freight_price`, which keeps the price on cancelled bookings too.
`weight_kg`, `total_cbm`, `total_ldm` and `packages` come from the goods lines,
aggregated to the booking before the join so no price is counted twice.
`freight_cost_per_kg` is per shipment.

`shipment_date` is the day the goods were collected, falling back to the planned
collection date and then to the booking date. `transit_days` is collection to
delivery in calendar days.

Carrier comes from the booking, falling back to the carrier on the booked offer.
`lane` is `collection_country → delivery_country`.

## Schema notes

- **`booking_rows` has no `index` column.** The table's own row key is `id`, not
  the `index` some schema listings show. Nothing here depends on either; rows are
  aggregated by `booking_reference`.
- **The company alias is not stored on the booking.** On a Cargoson account with
  several companies, the alias is not a column in `bookings`. If two companies ever
  reuse a booking reference, only one of the bookings appears. Join back to your own reference table
  if you need to split reports by company.
- **The connector does not sync carrier invoices, price breakdowns or tracking
  events.** Surcharges, fuel and per-event timelines are not available, which is why
  cost here is the agreed price and transit uses the milestone timestamps on the
  booking.

## Notes

- **Rates are ratios of sums.** `freight_cost_per_kg` in the monthly and lane models
  is total cost over total kilograms of the shipments that have both, so a single
  parcel does not weigh as much as a full truck. Never average the per-shipment
  `freight_cost_per_kg`.
- **Currency is in the grain.** Cargoson prices in the currency of the offer. A
  carrier that quotes some lanes in EUR and some in SEK gives two rows; convert at
  your own rate before adding them up.
- **The monthly model is built on a spine**, from the first month each carrier and
  service appears to the current month (or a later month if a collection is already
  planned), so a quiet month returns zeros instead of vanishing from a trend line.
- **Multi-account ready.** Every staging model emits a `cargoson_account` label and
  it is part of every join key and grain. To add a second Cargoson connection,
  `UNION ALL` a second block in each staging model with a different label, and
  change nothing else.
- **Nothing here has been run against a warehouse.** Reconcile one month's shipment
  count and spend per carrier against Cargoson's own shipment list and reports before
  relying on the output.

[Cargoson connector docs](https://weld.app/docs/applications/cargoson) ·
[Cargoson API reference](https://app.swaggerhub.com/apis-docs/cargoson/cargoson-api/v1)
