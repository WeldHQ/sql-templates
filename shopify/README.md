# Shopify templates

Rebuilds Shopify's sales reports in your warehouse. BigQuery, shop money.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_shopify__sales_over_time.sql) | "Total sales over time" | day × store × order × location × channel × row type |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_shopify__product_sales_over_time.sql) | "Total sales by product", reconciling | day × store × order × **line** |
| [`weld/core/sku_cost_per_day.sql`](weld/core/sku_cost_per_day.sql) | — (point-in-time cost, feeds COGS) | day × store × SKU |
| [`weld/core/sales_by_product.sql`](weld/core/sales_by_product.sql) | "Total sales by product", ranking only | product × variant × day |

**Two product models, deliberately.** `product_sales_over_time` is the real one: it
reads the agreement event log at line grain, so returns land on the refund date and
it **reconciles to `sales_over_time`**. `sales_by_product` is a cheap ranking query
off `order_line` — fine for "what sells", wrong for revenue that has to tie out. If
in doubt, use the first.

## Layers

Four of them, each with one job:

```
raw.shopify.*          ELT output, untouched
  ↓
weld/staging/*.sql     10 thin wrappers: cast, rename, drop test orders
  ↓
weld/core/*.sql        the reports - all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

**Staging** does the dull work once — cast types, rename, drop test orders, derive
`amount_ex_tax` — so core holds only reporting logic and adding a storefront is a
change in one place.

**Core** is where the sales equation, the parity variants and the dimensions live.
This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Dashboards, scheduled
reports and reverse-ETL syncs bind to `analytics.shopify.sales_over_time`, so core
can be renamed, re-grained or split without breaking anything downstream. Both are
currently `SELECT *` — that is the point, not an oversight. Put BI-specific shaping
here rather than in core.

`dbt/` holds the same models with dbt refs. They are generated from the Weld
versions, so the two dialects cannot disagree about the logic — see
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.shopify.order}}` expects the model in a `staging > shopify`
folder — mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `order`, `order_agreement`, `order_agreement_sale`, `order_line`, `order_refund`, `order_line_refund`, `shop`, `location`, `fulfillment` |
| product sales over time | the same, minus `fulfillment`, plus `inventory_item` and `inventory_item__history` for cost |
| sku cost per day | `order`, `order_line`, `shop`, `inventory_item`, `inventory_item__history` |
| sales by product | `order`, `order_line`, `product` |

**Costs come from Shopify, not a spreadsheet.** `inventory_item` carries the current
cost per SKU and `inventory_item__history` — Weld's history table for that stream —
carries every change. `sku_cost_per_day` picks the cost that was in effect on the day
of each sale, so a January order is valued at January's cost rather than today's.
Enable history tables on the `inventory_item` stream (Data Source → the stream →
History tables); without it, costs fall back to the current value.

## What sales_over_time returns

Grain is day × store × order × location × channel × row type. Row type being in
the grain means a day where an order both sells and refunds produces two rows, so
the SALE and RETURN sides stay independently auditable. Aggregate to day in BI.

**The sales equation.** `gross_sales`, `discounts`, `returns`,
`return_adjustments`, `net_sales`, `shipping_charges`, `duties`, `return_fees`,
`additional_fees`, `taxes`, `total_shopify_sales` (matches the admin UI) and
`total_sales` (excludes tax and duties — usually what finance wants).

**Parity variants**, because Shopify's admin UI and its CSV export disagree:
`net_sales_shopify_parity` excludes post-order edits while keeping checkout-flow
ones, and there are three quantity columns — `quantity` (net of returns),
`quantity_ordered_shopify_compat` (matches the UI) and
`quantity_ordered_shopify_export_parity` (matches the export).

**Returns detail.** `net_sales_reversals`, `gross_sales_reversals`,
`total_sales_reversals`, `discount_reversals`, `tax_reversals`,
`shipping_reversals`, `reversed_quantity`, plus `reversal_type` distinguishing a
CANCELLATION from a RETURN from a REFUND via `restock_type`.

**Gift cards**, kept out of the sales equation as deferred revenue:
`gift_card_gross_sales`, `gift_card_net_sales`, `gift_card_discounts`,
`gift_card_taxes`, `taxes_excluding_gift_cards`.

**Dimensions.** `location_name` (the order's own location, NULL when Shopify
recorded none — no label is invented for its absence), `refund_location_name`
(where a refund was processed, often not where the order was placed, so it is a
separate column rather than merged into the one above), `sales_channel`
(Shopify's own `source_name`: `web`, `pos`, `shopify_draft_order`, or an app
handle), `country` (cascading shipping → billing → location),
`fulfillment_status` (digital-only orders reported as `fulfillment_not_required`
rather than looking unfulfilled), `financial_status`, `is_cancelled`.

`location_name` and `sales_channel` are defined identically in
`sales_over_time` and `product_sales_over_time`, so the two reconcile on them.

**Counting.** `orders` counts an order once on its order date. `is_order_placed`
flags exactly one row per order on its first SALE day — sum it over any window for
the AOV denominator Shopify uses.

**Presentment money.** `presentment_currency`, `presentment_net_sales`,
`presentment_taxes` and `shopify_fx_rate` — Shopify's own implied rate per order.
Converting shop money at your own daily rate gives a number that does not match
what the customer paid, because Shopify used its rate at checkout.

## Notes

- **Timezone is read from `shop.iana_timezone`**, so nothing needs hardcoding.
  `happened_at` is UTC and Shopify reports store-local; getting this wrong puts
  every late-evening order on the wrong day.
- **Discounts and returns are stored negative**, so
  `net = gross + discounts + returns` is plain addition.
- **`sales_by_product` does not reconcile to `sales_over_time`.** It reads
  `order_line` on the order date, so returns stay attached to the original order
  rather than reducing the SKU that came back. Right for ranking, wrong for revenue
  that has to tie out.
- **Multi-store ready.** Every staging model emits a `shopify_store` label, and
  `shopify_store` is part of every join key and of the grain in core. To add a
  storefront, `UNION ALL` a second block in each staging model pointing at that
  store's connector with a different label - and change nothing else. Order IDs are
  only unique *within* a store, so dropping the key from one join would fan rows out
  across storefronts silently.

[How to build a Shopify sales report with SQL](https://weld.app/blog/shopify-sales-report-sql) ·
[dbt version](https://weld.app/blog/shopify-dbt-sales-model)
