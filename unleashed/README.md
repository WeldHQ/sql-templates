# Unleashed templates

Gross margin from completed sales, the stock position with reorder and slow-mover
flags, and the open order book, for inventory businesses on Unleashed. BigQuery.

Weld connector: **Unleashed** ([docs](https://weld.app/docs/applications/unleashed)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_margin.sql`](weld/core/sales_margin.sql) · [dbt](dbt/models/core/core_unleashed__sales_margin.sql) | Sales enquiry with gross margin | completed date × warehouse × customer × product × line type |
| [`weld/core/stock_position.sql`](weld/core/stock_position.sql) · [dbt](dbt/models/core/core_unleashed__stock_position.sql) | Stock on Hand with value, alert levels and days since last sale | product (all warehouses), current snapshot |
| [`weld/core/open_sales_orders.sql`](weld/core/open_sales_orders.sql) · [dbt](dbt/models/core/core_unleashed__open_sales_orders.sql) | Open sales orders and lateness | sales order, current snapshot |

## Layers

```
raw.unleashed.*        ELT output, untouched
  ↓
weld/staging/*.sql     4 thin wrappers: cast, rename, keep the latest version
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.unleashed.sales_order}}` expects the model in a `staging > unleashed` folder.

## Required tables

| Model | Raw tables |
|---|---|
| sales margin | `sales_order`, `sales_order_line`, `product` |
| stock position | `stock_on_hand`, `product` |
| open sales orders | `sales_order` |

## How margin is calculated

- **Completed orders only**, dated on `completed_date`. That is when Unleashed
  dispatches stock and fixes the cost.
- **Revenue** is `bc_line_total`: the line after discount, before tax, in the
  company's base currency.
- **Cost of goods** is quantity × `average_landed_price_at_time_of_sale`, the
  average landed cost Unleashed recorded on the line, also in base currency.
- **Charge lines** (freight and similar) carry revenue and no cost. `line_type` is
  part of the grain so they can be kept apart.
- **Credit notes are not netted off.** The `credit_note` and `credit_note_line`
  tables are available if you need returns in the margin.

## Schema notes

- **Stock on hand is synced for all warehouses combined.** `stock_on_hand` has one
  row per product with the warehouse fields empty, even though the raw table has
  warehouse columns. `stock_position` is therefore per product. Warehouse-level
  alert levels exist in `product_inventory_detail`, but warehouse-level quantities
  do not.
- **Deleted orders are synced as rows in `Deleted` status**, not removed. Every
  model filters on status.
- **Lines removed from an order may linger.** Order lines are a substream keyed on
  their own guid; a line deleted from a still-open order is not removed from the
  raw table. Completed orders are not edited in practice, so margin is not
  affected, but `open_sales_orders` reads header totals for that reason.
- **Two currencies on every order.** Columns prefixed `bc_` are base currency;
  the others are in the order's currency, with `exchange_rate` between them.

## Reconciling

Nothing here has been run against a live warehouse. Run Unleashed's Sales
Enquiry for completed orders last month and compare revenue and margin with
`sales_margin` for the same dates; compare `stock_position` value with the Stock on
Hand report's total. [`tests/assert_unleashed__margin_reconciles_to_orders.sql`](dbt/tests/assert_unleashed__margin_reconciles_to_orders.sql)
checks that line revenue adds up to the order sub totals.

[Unleashed API](https://apidocs.unleashedsoftware.com/) ·
[sales orders](https://apidocs.unleashedsoftware.com/SalesOrders) ·
[stock on hand](https://apidocs.unleashedsoftware.com/StockOnHand)
