# TikTok Shop templates

Rebuilds TikTok Shop sales reporting in your warehouse, from orders and returns,
and adds the part Seller Center makes hard to see: what TikTok actually paid out
after commission, fees and shipping. BigQuery.

Weld connector: **TikTok Shop**
([docs](https://weld.app/docs/applications/tiktok-shop)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_tiktok_shop__sales_over_time.sql) | Sales equation per day, with shipping and tax | day × account × shop × currency × row type |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_tiktok_shop__product_sales_over_time.sql) | The same equation by product and SKU, reconciling to the above | day × account × shop × currency × product × SKU × row type |
| [`weld/core/settlement_ledger.sql`](weld/core/settlement_ledger.sql) · [dbt](dbt/models/core/core_tiktok_shop__settlement_ledger.sql) | What TikTok paid you, itemised, tying to each statement | statement × account × shop × transaction |
| [`weld/core/shop_performance.sql`](weld/core/shop_performance.sql) · [dbt](dbt/models/core/core_tiktok_shop__shop_performance.sql) | TikTok's own shop analytics: GMV, orders, buyers, page views | day × account × shop |

Row type is `SALE`, `CANCELLATION` or `RETURN`. Sum over it in BI; it is in the
grain so the sale side and the reversal side can be audited separately.

## Read this first

- **Nothing here has been run against a warehouse.** The models parse, every
  reference resolves, and every column was checked against the connector's
  schema, but no output has been compared with a real shop. Reconcile one month
  against Seller Center (Finance → Statements for the ledger, Data Compass for
  the analytics) before relying on it.
- **Set the timezone.** TikTok sends UTC timestamps and Seller Center reports in
  the shop's local time (Pacific for US shops). Edit `report_timezone` in
  [`weld/staging/shop.sql`](weld/staging/shop.sql); left at `UTC`, late-evening
  orders land on the next day.
- **Three different revenue numbers, all correct.** `net_sales` is what customers
  paid for products after cancellations and refunds. TikTok's GMV in
  `shop_performance` is TikTok's own definition. `settlement_amount` in the
  ledger is cash, dated by statement. Expect them to differ.

## Layers

```
raw.tiktok_shop.*             ELT output, untouched
  ↓
weld/staging/*.sql            8 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql               the reports, all the business logic lives here
  ↓
weld/analytics/*.sql          BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps the latest version of each row, so core
holds only reporting logic. It also leaves out buyer names, addresses and contact
details, which no report here needs.

**Core** is where the sales equation, the cancellation and refund rules and the
ledger live. This is the layer worth reviewing.

**Analytics** is `SELECT *` over core by design. Dashboards bind to
`analytics.tiktok_shop.*`, so core can change without breaking them.

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.tiktok_shop.order}}` expects the model in a
`staging > tiktok_shop` folder.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `order`, `order_line_items`, `return_order`, `return_order_line_items` |
| product sales over time | the same |
| settlement ledger | `statement_transaction_report`, `statement` |
| shop performance | `shop_performance` |

`order` also feeds `weld/staging/shop.sql`, which holds the timezone.

## What sales_over_time returns

The sales equation, every reversal stored negative so it is plain addition:

```
net_sales   = gross_sales + seller_discounts + platform_discounts
            + cancellations + returns
total_sales = net_sales + shipping + taxes
```

- `gross_sales`: list price of every unit sold.
- `seller_discounts`: discounts you fund.
- `platform_discounts`: discounts TikTok funds. The customer did not pay them, so
  they reduce `net_sales`, but TikTok pays them back to you in settlement. Your
  product revenue before fees is `net_sales - platform_discounts`.
- `cancellations`: what customers paid for lines TikTok marks cancelled, on the
  cancellation day.
- `returns`: refunded product value, on the day the return or refund completed.
- `shipping` and `taxes`: order level, reversed when a whole order is cancelled
  and when a refund includes them.
- `orders`: orders counted once, on their paid day. `units`: net units.

## Schema notes

- **One line item is one unit.** TikTok's order API has no quantity field: three
  of the same SKU arrive as three line items. Units are counted, never summed.
- **Return lines carry no product id.** It is resolved through
  `order_line_item_id` to the order line.
- **`statement_transaction` is retired.** `statement_transaction_report`
  replaces it and has the full fee breakdown. Only the
  latter is used here.
- **`statement.statement_time` is Unix seconds** stored as a number; staging
  converts it.
- The ERD and the connector's own schema agree on every column used here.

## Notes

- **Unpaid, sample and replacement orders are left out.** Unpaid orders have no
  money yet. Free samples sent to creators and free replacements would add units
  at zero price. Cash-on-delivery orders count from their created time.
- **There is no refund timestamp.** A completed return's last update time is used
  as the refund date. An edit to a return after it completed (an arbitration
  outcome, for example) moves it.
- **A cancelled line inside a shipped order** reverses its product value on the
  order's cancel time (or last update), and does not reverse shipping. A line
  that was both cancelled and given a refund record is reversed once.
- **Partial refunds** offered by the seller are recorded at return level
  (`partial_refund_amount`); the line refund amounts are used here. If you use
  partial refunds heavily, check refunded totals against Seller Center.
- **Fees are dated by statement, not by order.** Compare fee rates per order or
  over a long window, never one month of fees against the same month of sales.
- **`unexplained_amount` in the ledger** shows any part of a transaction's
  settlement that revenue, fees, shipping and adjustments do not explain. It
  should be zero or close to it; watch it if TikTok adds a component.
- **Shop analytics** come only for shops in the US, UK, Singapore, Vietnam and
  Thailand. Elsewhere `shop_performance` is empty.
- **Multi-account ready.** The connector can sync several shops in one
  connection, keyed by `shop_id`. Every staging model also emits a
  `tiktok_account` label, part of every join key and grain; to add a second
  connection, `UNION ALL` a second block in each staging model with a different
  label.

## TikTok documentation

- [TikTok Shop Partner Center API reference](https://partner.tiktokshop.com/docv2) (Order, Return and Refund, Finance and Analytics sections)
