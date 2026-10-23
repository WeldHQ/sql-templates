# Traede templates

Wholesale reporting from Weld's Traede connector: invoiced revenue, product sales
with margin, the open order book and inbound production. BigQuery, invoice currency.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/invoiced_sales_over_time.sql`](weld/core/invoiced_sales_over_time.sql) · [dbt](dbt/models/core/core_traede__invoiced_sales_over_time.sql) | What did we invoice, per day, split B2B and B2C | day × account × currency |
| [`weld/core/product_sales.sql`](weld/core/product_sales.sql) · [dbt](dbt/models/core/core_traede__product_sales.sql) | Which styles and SKUs sell, and at what margin | day × account × currency × variant |
| [`weld/core/order_book.sql`](weld/core/order_book.sql) · [dbt](dbt/models/core/core_traede__order_book.sql) | What is ordered but not yet shipped or invoiced | order line (order × variant) |
| [`weld/core/production_order_status.sql`](weld/core/production_order_status.sql) · [dbt](dbt/models/core/core_traede__production_order_status.sql) | What is coming from suppliers, and is it late | production order line |

## Read this first: what this connector cannot do

**1. Credit notes are not synced.** Traede keeps credit notes as their own resource
and the connector does not sync it. Every revenue number here is invoiced revenue
**before credits and returns**. If you issue many credit notes, reconcile against
Traede's own revenue figures with that in mind.

**2. Cost is current, and its currency is undocumented.** The variant's
`cost_price` is what the SKU costs today; there is no cost history on the stream,
so last season's sales are valued at this season's cost. Traede does not document
which currency the field is in. `product_sales` treats it as the account's base
currency, set in one line at the top of the model (`'EUR'` by default). Margin is
only computed for invoice lines in that currency; other currencies return NULL
cost and margin rather than subtracting one currency from another.

**3. Nothing converts currencies.** Traede invoices each customer in its own
currency and the connector syncs no exchange rates, so currency is part of every
money grain. Convert in BI or join your own FX table before summing.

**4. The order book is current state.** Orders sync as they are now. To trend the
book or order intake against what was open last month, materialise `order_book` on
a schedule and keep the runs.

## Layers

```
raw.traede.*            ELT output, untouched
  ↓
weld/staging/*.sql      11 thin wrappers: cast, rename, parse flags and dates
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and normalises. It also makes Traede's price fields
safe to sum: on order and invoice headers `net_price` is a total, on lines the same
name is a **unit** price. Staging renames them `net_amount` and `unit_net_price`,
and multiplies the per-unit gross and discount out on invoice lines.

**Core** holds the booked-invoice filter, the order-book logic and the margin
calculation. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards to
`analytics.traede.invoiced_sales_over_time` so core stays free to be renamed or
re-grained. All four are `SELECT *`, which is the point.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.traede.invoice}}` expects the model in a `staging > traede`
folder; mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| invoiced sales over time | `invoice` |
| product sales | `invoice`, `invoice_line`, `variant`, `product` |
| order book | `order`, `order_line`, `customer`, `variant`, `product` |
| production order status | `production_order`, `production_order_line`, `variant`, `product` |

`invoice_line` and `order_line` arrive with the `invoice` and `order` streams;
`variant` and `product` are separate streams and need to be enabled for SKU and
style names.

Synced but not modelled: stock (`variant_stock` / `variant_available`, which of
the two is populated depends on whether the Traede account uses reservations, and
both are current state only), delivery notes, prices, categories and the
key/value `*_meta` tables that hold custom fields.

## What invoiced_sales_over_time returns

One row per day, account and currency, from the first booked invoice to today, with
zeros on days without invoices. `invoices`, `invoiced_customers`,
`units_invoiced`, then the money: `gross_sales` less `discounts` is `net_sales`
(ex VAT, before shipping and handling), with `shipping`, `handling_fees`, `vat`
and `total_incl_vat` alongside. `b2b_net_sales`, `b2c_net_sales` and
`other_net_sales` split net sales by Traede's order type; other covers `pos`,
`move` and `consignment`. `draft_invoices` and `draft_net_amount` show unbooked
drafts dated on the same day, as a backlog signal.

Only invoices with status `booked` count as revenue. The invoice date is Traede's
`invoice_date`, falling back to the creation date when it is empty.

## Notes

- **`product_sales` sums line revenue**, which excludes shipping and handling and
  any discount set on the invoice header. It sits below `invoiced_sales_over_time`
  by exactly those amounts. Units match exactly; the
  [`assert_traede__line_units_match_invoice_units`](dbt/tests/assert_traede__line_units_match_invoice_units.sql)
  test checks that.
- **Margin percentage is not stored per row.** Compute it in BI as
  `SUM(gross_margin) / SUM(net_sales_with_cost)`. Averaging row percentages weights
  a one-unit day the same as a thousand-unit day.
- **"Open" in the order book means not yet released to the warehouse.** Traede's
  `shipped` quantity rises when units are sent to the warehouse for picking, not
  when the customer receives them. Draft and selection orders are returned with
  `is_open = FALSE`.
- **`move` orders are stock movements**, not sales. They are kept in
  `order_book` with their `order_type` so you can filter them; they are counted in
  `other_net_sales` only if they were invoiced.
- **Supplier currency is not synced** on production orders, so do not sum
  `outstanding_cost_amount` across suppliers that bill in different currencies.
- **Deletes.** Traede supports soft deletes in Weld. With soft deletes enabled, a
  full re-sync marks rows removed in Traede (including lines removed from an
  order) as deleted; filter those out in staging if you enable it.
- **Multi-account ready.** Every staging model emits a `traede_account` label and
  it is part of every join key and grain. To add a second Traede brand, `UNION ALL`
  a second block in each staging model with a different label, and change nothing
  else.
- **Not run against a warehouse.** These models have been parsed and checked
  against the connector's schema, not run on live data. Reconcile a month of
  `invoiced_sales_over_time` against Traede's own invoice list before relying on
  it.

## Schema notes

The table and column names used here match both the public schema and the
connector's own stream definitions. Two things worth knowing:

- `invoice.invoice_date` lands as a string, not a date. Staging parses the first
  ten characters.
- `order.cancelled` and `order.archived` are booleans in Traede's API but land as
  strings. Staging parses `true` / `1` / `yes`.

[Traede connector docs](https://weld.app/docs/applications/traede) ·
[Traede Core API: invoices](https://developer.traede.com/core-api/invoices/the-invoice-object) ·
[orders](https://developer.traede.com/core-api/orders/the-order-object) ·
[order types](https://developer.traede.com/core-api/orders/order-types) ·
[production orders](https://developer.traede.com/core-api/production-orders/the-production-order-object)
