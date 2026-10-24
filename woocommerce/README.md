# WooCommerce templates

Rebuilds WooCommerce Analytics' Revenue, Products and Customers reports in your
warehouse. BigQuery, store currency, store-local time.

Weld connector: **WooCommerce** ([docs](https://weld.app/docs/applications/woocommerce)).
It replicates your store's own MySQL tables, so these models read WooCommerce's
database schema directly.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_woocommerce__sales_over_time.sql) | Analytics "Revenue" (and the totals of "Orders") | day × store × order × row type |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_woocommerce__product_sales_over_time.sql) | Analytics "Products" and "Variations" | day × store × order × line |
| [`weld/core/customers.sql`](weld/core/customers.sql) · [dbt](dbt/models/core/core_woocommerce__customers.sql) | Analytics "Customers" | store × customer |

## Read this first

**1. Everything reads WooCommerce Analytics' lookup tables.** `wc_order_stats`,
`wc_order_product_lookup` and `wc_customer_lookup` are what WooCommerce's own
Analytics screens query. They are filled the same way whether your orders live in
`wp_posts`/`wp_postmeta` (legacy storage) or in the newer order tables (HPOS), so
these models work on both without knowing which one you use. The price is that the
tables are only as complete as WooCommerce has made them: if Analytics is disabled,
or the historical import (Analytics → Settings, "Import
historical data") was never run, older orders are missing and every model here
starts at the date the store began writing them. Compare
`MIN(date)` in `sales_over_time` with your first order before trusting a
year-over-year number.

**2. Your table prefix may not be `wp_`.** WordPress lets each install choose its
table prefix, and the raw tables land under whatever yours is (`wp_wc_order_stats`,
`shop_wc_order_stats`, ...). The staging models use the default `wp_`. If yours
differs, change the raw table name in the seven files in `weld/staging/` and
nothing else.

**3. Coupons come from product lines, not the coupon table.** Analytics reads its
"Coupons" figure from `wc_order_coupon_lookup`, which is not among the synced
tables. `discounts` is the sum of the coupon value WooCommerce allocated to each
product line in `wc_order_product_lookup`. It is the same money spread across lines,
so totals should agree to the cent or within rounding; it cannot give you a
per-coupon breakdown.

**4. There is no per-order currency or address here.** The store currency comes from
the `woocommerce_currency` setting and is the *current* one. If you run a
multi-currency plugin, amounts are summed across currencies exactly as WooCommerce
Analytics does, which is wrong for both. Customer location is the customer's latest
billing address, not the address on each order.

## Layers

```
raw.woocommerce.*         your store's MySQL tables, replicated untouched
  ↓
weld/staging/*.sql        7 thin wrappers: cast, rename, dedupe, filter
  ↓
weld/core/*.sql           the reports: all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

**Staging** casts, renames, keeps the latest copy of each row, and picks the few
rows needed out of WordPress' generic tables (`wp_posts` down to products and
variations, `wp_postmeta` down to `_sku`, `wp_options` down to three settings). It
also turns WooCommerce's local DATETIME columns into DATETIME values; see Notes.

**Core** holds the sales equation and the Analytics rules (report date, excluded
statuses). This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards to
`analytics.woocommerce.sales_over_time` so core stays free to be renamed or
re-grained. All three are `SELECT *`.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.woocommerce.order_stats}}` expects the model in a
`staging > woocommerce` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables (default `wp_` prefix) |
|---|---|
| sales over time | `wp_wc_order_stats`, `wp_wc_order_product_lookup`, `wp_options` |
| product sales over time | the same, plus `wp_woocommerce_order_items`, `wp_posts`, `wp_postmeta` |
| customers | the sales over time tables, plus `wp_wc_customer_lookup` |

**Synced but not used.** The HPOS order tables (`wc_orders`, `wc_order_addresses`,
`wc_order_operational_data`) and `woocommerce_order_itemmeta` hold per-order
currency, payment method, billing and shipping addresses and line metadata. They are
left out so the models work on stores that do not use HPOS, and because the lookup
tables already carry the money. Add them in a staging model if you need order-level
geography or payment method.

**Not synced, and what they would unlock:**

| WooCommerce table | Would add |
|---|---|
| `wc_order_coupon_lookup` | Analytics' exact coupon figure, and a per-coupon report |
| `wc_order_tax_lookup` | taxes by tax rate (the Taxes report) |
| `wc_category_lookup` | sales by product category including parent categories, the way the Categories report rolls them up |
| `wc_product_meta_lookup` | SKU, stock and price per product without reading `wp_postmeta` |

`wp_terms`, `wp_term_taxonomy` and `wp_term_relationships` are synced, so a flat
sales-by-category view can be built today. It is left out because a product can sit
in several categories: such a report counts one sale once per category, so its rows
never add up to total sales, and that is easy to misread.

## What sales_over_time returns

Grain is day × store × order × row type. `row_type` is `SALE` for the order and
`RETURN` for its refunds; `order_id` is the original order on both, so an order and
its refunds group together.

**The sales equation.** `gross_sales`, `discounts`, `returns`, `net_sales`,
`shipping`, `taxes`, `total_sales`. Discounts and returns are negative, so
`net_sales = gross_sales + discounts + returns` is plain addition, and
`net_sales` is exactly WooCommerce's "Net sales". `total_sales` is Analytics'
"Total sales": the order totals including tax and shipping, net of refunds.

**Refunds, two ways.** `returns` is the refunded amount before tax and shipping.
`returns_incl_tax_and_shipping` is the whole refund. Recent WooCommerce versions
show the second (as a positive number) as "Refunds"; older ones show the first.

**Counting.** `orders` is 1 on an order's SALE row and 0 on RETURN rows; sum it over
any window for "Orders", the average order value denominator. `items_sold` is net of
refunded items. `is_returning_customer` is WooCommerce's own flag.

**The Analytics rules, read from your settings.** The report date follows the
"Date type" setting (date paid by default), and statuses in the "Excluded statuses"
setting (pending, failed and cancelled by default) are left out, together with their
refunds. Both come from `wp_options` through `staging/store_settings.sql`, so the
models follow your configuration rather than a guess at it. Rows without a value
for the chosen date (an unpaid order under "date paid") are left out, as Analytics
does.

## Notes

- **Times are store-local and need no conversion.** WooCommerce writes
  `date_created`, `date_paid` and `date_completed` as local wall-clock time with no
  zone. They arrive in the warehouse as timestamps whose UTC reading is that wall
  clock, so staging converts them with `DATETIME(ts, 'UTC')`, which gives back the
  local value exactly. Converting to your time zone again would shift every order.
- **`parent_id != 0` means refund.** That is how WooCommerce Analytics reads it too.
  Plugins that create child orders (marketplace sub-orders, for example) also set a
  parent, and Analytics, and these models, treat those rows as refunds. If you run
  one, check `sales_over_time` for RETURN rows with positive amounts.
- **`product_sales_over_time` does not sum to `sales_over_time`.** It holds product
  lines only: fees, shipping lines and lump-sum refunds that are not tied to a
  product are in the order totals and not in the lines. Discounts do tie, and
  [`assert_woocommerce__product_discounts_tie_to_orders`](dbt/tests/assert_woocommerce__product_discounts_tie_to_orders.sql)
  checks it.
- **Deleted orders.** WooCommerce deletes an order's Analytics row when the order is
  deleted. Unless the connection uses change data capture, a deleted row stays in
  your warehouse; run a full resync of `wc_order_stats` if your totals must match
  after deletions.
- **Multi-store ready.** Every staging model emits a `woocommerce_store` label, and
  it is part of every join key and of the grain in core. To add a store, `UNION ALL`
  a second block in each staging model pointing at that store's tables with a
  different label, and change nothing else. Order ids are only unique within a store.
- **Not run against a warehouse.** Nothing here has been run against real data.
  Reconcile a month against WooCommerce → Analytics → Revenue (same date range, same
  date type) before relying on the output.

[WooCommerce Analytics documentation](https://woocommerce.com/document/woocommerce-analytics/) ·
[Order data storage (HPOS)](https://developer.woocommerce.com/docs/best-practices/data-management/data-storage/) ·
[WooCommerce database schema](https://developer.woocommerce.com/docs/woocommerce-database-schema/)
