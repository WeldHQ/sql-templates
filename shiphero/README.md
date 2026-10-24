# ShipHero templates

Fulfilment reporting from Weld's ShipHero connector: throughput and shipping cost
per warehouse, order-level SLA, return rates by SKU and picker/packer
productivity. BigQuery, UTC days.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/fulfillment_by_day.sql`](weld/core/fulfillment_by_day.sql) · [dbt](dbt/models/core/core_shiphero__fulfillment_by_day.sql) | How much did we ship, what did labels cost, how much went out on time | day × account × warehouse |
| [`weld/core/order_fulfillment.sql`](weld/core/order_fulfillment.sql) · [dbt](dbt/models/core/core_shiphero__order_fulfillment.sql) | When did each order ship, was it late, what did shipping cost against what was charged | order |
| [`weld/core/product_returns_by_month.sql`](weld/core/product_returns_by_month.sql) · [dbt](dbt/models/core/core_shiphero__product_returns_by_month.sql) | Which SKUs come back, and how often | month × account × ShipHero account_id × SKU |
| [`weld/core/warehouse_productivity.sql`](weld/core/warehouse_productivity.sql) · [dbt](dbt/models/core/core_shiphero__warehouse_productivity.sql) | Picks and packs per person per day | day × account × warehouse × user |

## Read this first: what this connector cannot do

**1. Shipment and return statuses lag.** Shipments and returns are picked up by
**creation date**. Anything that changes afterwards, a shipment being
delivered or a return being received and restocked, only reaches the warehouse
when that period is read again. That is why nothing here reports delivery times,
and why `units_received` and `units_restocked` on returns should be treated as a
floor. Orders, by contrast, are picked up by update time and stay current.

**2. There is no ship date per order line.** `order_line_item` carries how many
units have shipped, not when. Units shipped by SKU therefore land on the order
date in `product_returns_by_month`, while returns land on the date the return was
created. Read return rates over a quarter or more.

**3. There is no warehouse name.** The connector syncs warehouse ids, not a
warehouse table, so every model groups by `warehouse_id`. Map ids to names in BI.

**4. No shift data.** The pick and pack logs record events, not hours worked, so
units per hour cannot be computed. `first_activity_at` and `last_activity_at`
bound each person's working span per day as a proxy.

## Layers

```
raw.shiphero.*          ELT output, untouched
  ↓
weld/staging/*.sql      11 thin wrappers: cast, rename, money strings to NUMERIC
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts and renames. ShipHero's API returns every money field as a
string; staging `SAFE_CAST`s them so a malformed value becomes NULL rather than
failing the run.

**Core** aggregates every child table to its parent before joining, so an order
with three shipments and five lines is still one row. This is the layer worth
reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards to
`analytics.shiphero.fulfillment_by_day` so core stays free to be renamed or
re-grained. All four are `SELECT *`, which is the point.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.shiphero.shipment}}` expects the model in a
`staging > shiphero` folder; mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| order fulfillment | `order`, `order_line_item`, `order_shipping_line`, `shipment`, `shipment_shipping_label` |
| fulfillment by day | the same, plus `shipment_line_item` |
| product returns by month | `order`, `order_line_item`, `return`, `return_line_item`, `product` |
| warehouse productivity | `pick_per_day`, `pack_per_day` |

Line items, shipping lines and labels arrive with the `order`, `shipment` and
`return` streams. `product`, `pick_per_day` and `pack_per_day` are separate
streams.

Synced but not modelled: `warehouse_product` (current on-hand, allocated and
available per SKU per warehouse, already report-shaped as it lands),
`inventory_change` (the stock movement log, whose `reason` is free text),
purchase orders and wholesale orders.

## What fulfillment_by_day returns

One row per day and warehouse, from the warehouse's first shipment to today, with
zeros on quiet days.

**Throughput and cost, on the shipment date:** `shipments`, `orders_shipped`,
`packages`, `units_shipped`, `labels`, `refunded_labels` and `label_cost`. Label
cost excludes refunded (voided) labels.

**SLA, on the date of each order's first shipment, once per order:**
`orders_first_shipped`, `orders_with_required_date`, `orders_shipped_on_time` and
`hours_to_first_shipment_total`. On time means the first shipment went out on or
before ShipHero's `required_ship_date`.

Compute rates over the window in BI, never as an average of daily rates:
on-time rate is `SUM(orders_shipped_on_time) / SUM(orders_with_required_date)`,
cost per shipment `SUM(label_cost) / SUM(shipments)`, mean time to ship
`SUM(hours_to_first_shipment_total) / SUM(orders_first_shipped)`.

## Notes

- **Time to ship is measured from the store order date** (`order_date`), falling
  back to when the order reached ShipHero. Orders held on purpose (fraud, address
  or payment holds, `hold_until_date`) count their hold time; filter on those if
  your SLA excludes them.
- **`is_shipped_on_time` is NULL** for orders without a required ship date or not
  yet shipped. `is_late_unshipped` flags open orders already past their date.
- **`shipping_margin`** on `order_fulfillment` is what the customer was charged for
  shipping (from the store, via `order_shipping_line`) minus label cost. Negative
  means shipping was subsidised.
- **Days are UTC.** A US warehouse sees late-evening shipments on the next UTC
  day. Convert with `DATETIME(ts, 'America/New_York')` in core if your SLA is
  measured in local time.
- **3PLs.** `account_id` on orders and returns is the ShipHero account that owns
  them, which for a 3PL is the brand. It is carried on `order_fulfillment` and is
  part of the grain in `product_returns_by_month`, because two brands can use the
  same SKU string.
- **Multi-account ready.** Every staging model emits a `shiphero_account` label and
  it is part of every join key and grain. To add a second ShipHero connection,
  `UNION ALL` a second block in each staging model with a different label, and
  change nothing else.
- **Not run against a warehouse.** These models have been parsed and checked
  against the connector's schema, not run on live data. Reconcile a week of
  `fulfillment_by_day` against ShipHero's shipment and picks/packs reports before
  relying on it.

## Schema notes

The table and column names used here match both the public schema and the
schema Weld syncs. Money fields (`cost`, `price`, `total_price`,
`label_cost` and others) land as strings and are cast in staging.

[ShipHero connector docs](https://weld.app/docs/applications/shiphero) ·
[ShipHero API schema](https://developer.shiphero.com/schema/) ·
[ShipHero developer docs](https://developer.shiphero.com/)
