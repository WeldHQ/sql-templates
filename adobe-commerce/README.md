# Adobe Commerce templates

Rebuilds the Adobe Commerce (Magento 2) admin Orders sales report in your
warehouse, adds a sales equation and product-level sales, and puts a rate of sale
next to stock. BigQuery, global currency.

Weld connector: **Adobe Commerce** ([docs](https://weld.app/docs/applications/adobe-commerce)).
It replicates your store's own MySQL tables, so these models read the Magento
database schema directly. They apply equally to a Magento Open Source database.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_adobe_commerce__sales_over_time.sql) | Reports > Sales > Orders, plus the sales equation | day × store × order |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_adobe_commerce__product_sales_over_time.sql) | Products Ordered / Bestsellers, with money and cost | day × store × order × item |
| [`weld/core/inventory_cover.sql`](weld/core/inventory_cover.sql) · [dbt](dbt/models/core/core_adobe_commerce__inventory_cover.sql) | Low Stock, plus days of cover | store × product × stock × website (point in time) |

## Read this first: what the synced tables cannot do

The connector syncs five tables for this source: `sales_order`, `sales_order_item`,
`catalog_product_entity`, `cataloginventory_stock_item` and `email_contact`. Three
limits follow from that, and they are properties of the table set, not of these
models.

**1. Refunds land on the order date, not the refund date.** A Magento order is one
row whose `*_refunded` and `*_canceled` columns are running totals, updated in
place. When and in how many steps the money went back is recorded in the credit
memo tables (`sales_creditmemo`, `sales_creditmemo_item`), which are not synced. So
`returns` reduces the day the order was *placed*, and past days change whenever an
old order is refunded. Last month's net sales will drift down for weeks as returns
come in. That is the same answer the admin Orders report gives when run by order
date; it is not what a finance close wants. There is no honest refund-date view
from these tables.

**2. Set your time zone by hand.** Order times are stored in UTC and the admin
reports convert them to the store's configured time zone, which lives in
`core_config_data` (not synced). Edit
[`weld/staging/store_timezone.sql`](weld/staging/store_timezone.sql); left at UTC,
late-evening and early-morning orders land on the wrong day.

**3. No product names, categories, addresses or store names beyond the order.**
Magento keeps product attributes (name, price, cost, status) in EAV tables such as
`catalog_product_entity_varchar`, and store, website, customer and address data in
their own tables, none of them synced. Product names come from the order item,
which is the name at the time of sale; stores appear as `store_id` only; there is
no shipping country.

`email_contact` is synced but not used: it is the Dotdigital email extension's
contact table, with no money or order data.

## Layers

```
raw.adobe_commerce.*        your store's MySQL tables, replicated untouched
  ↓
weld/staging/*.sql          5 thin wrappers: cast, rename, dedupe, normalise signs
  ↓
weld/core/*.sql             the reports: all the business logic lives here
  ↓
weld/analytics/*.sql        BI-facing contracts, deliberately thin
```

**Staging** casts, renames, keeps the latest copy of each row, turns NULL amounts
into 0, and normalises Magento's discount signs (negative on the order, positive on
items) to positive magnitudes so core applies the sign once. `store_timezone.sql`
is a one-row settings model with no raw source.

**Core** holds the report rules and the sales equation. This is the layer worth
reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards to
`analytics.adobe_commerce.sales_over_time` so core stays free to change. All three
are `SELECT *`.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.adobe_commerce.sales_order}}` expects the model in a
`staging > adobe_commerce` folder. Mirror that structure in your synced repo, or
adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `sales_order`, `sales_order_item` |
| product sales over time | `sales_order`, `sales_order_item` |
| inventory cover | `cataloginventory_stock_item`, `catalog_product_entity`, `sales_order`, `sales_order_item` |

If your database uses a table prefix (set at install time, for example
`mage_sales_order`), the raw tables land under the prefixed names: change the raw
table name in each staging model.

**Not synced, and what they would unlock:**

| Magento table | Would add |
|---|---|
| `sales_creditmemo`, `sales_creditmemo_item` | returns on the refund date, so history stops restating |
| `sales_invoice`, `sales_invoice_item` | sales by invoice date (the admin report's "Last Updated" and invoiced views) |
| `core_config_data` | the store time zone, read instead of hardcoded |
| `store`, `store_website` | store view and website names |
| `sales_order_address` | shipping and billing country per order |
| `catalog_product_entity_varchar` / `_decimal`, `eav_attribute` | current product names, prices and costs |
| `catalog_category_product`, `catalog_category_entity_varchar` | sales by category |
| `inventory_source_item` | stock per source for Multi-Source Inventory |
| `sales_order_payment` | payment method |

## What sales_over_time returns

Grain is one row per order, dated by its creation day in your time zone.

**The sales equation**, in the global currency: `gross_sales` (subtotal less
canceled subtotal), `discounts`, `returns` (refunded amount less refunded tax and
shipping, including credit memo adjustments, which are also broken out as
`return_adjustments`), `net_sales`, `shipping`, `taxes`, `total_sales`. Discounts
and returns are negative, so `net_sales = gross_sales + discounts + returns` is
plain addition.

**The admin report's own columns**, with Magento's definitions: `sales_total`
(grand total less canceled), `invoiced`, `paid`, `refunded`, `canceled`,
`sales_tax`, `sales_shipping`, `sales_discount` (positive, as the report shows it),
`revenue` and `profit`. `profit` uses `base_total_invoiced_cost`, which is only
non-zero for products with a cost attribute.

**Counting.** `orders` is 1 per row; `items_ordered` is the report's "Sales Items"
(ordered less canceled, top-level items only, so a configurable product counts
once).

**Which orders.** Orders in state `new` or `pending_payment` are left out, as the
admin report does. Canceled orders stay in with their canceled amounts subtracted;
`is_canceled` lets you drop them.

## Notes

- **Global currency, as the admin report.** Amounts are base currency ×
  `base_to_global_rate`. With one website, or one base currency, that rate is 1. A
  missing rate is treated as 1; Magento's report treats it as 0, which drops the
  order from its totals.
- **Discount tax compensation.** When catalog prices include tax, Magento adds a
  small "discount tax compensation" to the grand total that is in none of the
  equation's columns, so `total_sales` can differ from `sales_total` by that
  amount.
- **Configurable and bundle products.** Product sales read top-level item rows:
  the configurable parent (which carries the price and the selected simple SKU) or
  the bundle itself. Bundles with dynamic pricing can carry their money on the
  component rows instead;
  [`assert_product_sales_tie_to_orders`](dbt/tests/assert_product_sales_tie_to_orders.sql)
  lists any order where item gross sales do not add up to the order's.
- **Cost of goods** uses `base_cost`, the product cost copied onto the order item
  when the order was placed. It is NULL, not zero, when no cost was set, and so is
  `gross_margin`.
- **Inventory is a snapshot.** `inventory_cover` reflects stock at the last sync.
  For Multi-Source Inventory with more than one source it reads the default source
  only.
- **Multi-store ready.** Every staging model emits an `adobe_commerce_store` label,
  and it is part of every join key and of the grain in core. To add a second Adobe
  Commerce database, `UNION ALL` a second block in each staging model with a
  different label, and add a row to `store_timezone.sql`. Order ids are only unique
  within one database.
- **Not run against a warehouse.** Nothing here has been run against real data.
  Reconcile a month against Reports > Sales > Orders (same period, "Order Created"
  date, refreshed statistics) before relying on the output.

[Adobe Commerce sales reports](https://experienceleague.adobe.com/en/docs/commerce-admin/start/reporting/sales-reports) ·
[Reports menu](https://experienceleague.adobe.com/en/docs/commerce-admin/start/reporting/reports-menu)
