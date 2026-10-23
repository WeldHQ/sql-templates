# Salesforce Commerce Cloud templates

Order and product sales from Weld's Salesforce Commerce Cloud (B2C Commerce)
connector. BigQuery, the order's own currency.

Weld connector: **Salesforce Commerce Cloud**
([docs](https://weld.app/docs/applications/salesforce-commerce-cloud)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_salesforce_commerce_cloud__sales_over_time.sql) | Gross, item and order discounts, net, shipping, tax and total per day and site | day × instance × site × order |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_salesforce_commerce_cloud__product_sales_over_time.sql) | The same equation per product line | day × instance × site × order × product line |

## Read this first

Nothing here has been run against a warehouse. Reconcile a closed month against
Business Manager's order search, or your order management system, before relying on
it. Three properties of the source decide what can be built:

**1. There are no returns or refunds.** The connector syncs five streams: `order`,
`product`, `catalog`, `category` and `customer`. Nothing records a return, a refund
or a payment capture. So these are sales models, not net-of-returns models: there
is no RETURN row type, and a cancelled order simply drops out of the day it was
placed. If returns matter, they live in your order management or payment system
and have to be joined in from there.

**2. Order lines are JSON.** The connector flattens nested objects on the order into
columns (`billing_address_city`, `customer_info_email`) but stores arrays as JSON
text, so `product_items`, `shipments`, `payment_instruments`,
`order_price_adjustments` and `coupon_items` each arrive as one string.
[`weld/staging/order_product_item.sql`](weld/staging/order_product_item.sql) parses
`product_items` into one row per line, once. It reads each field under both its
camelCase and snake_case key, because the two Commerce Cloud APIs spell them
differently. The parse is the least certain part of this package:
[`assert_salesforce_commerce_cloud__product_lines_parse`](dbt/tests/assert_salesforce_commerce_cloud__product_lines_parse.sql) checks that
the parsed lines add back up to Commerce Cloud's own `product_sub_total` on every
order, and `sales_over_time.unparsed_line_amount` shows the gap per order.

**3. The site's time zone is not synced.** Order timestamps are UTC. Set
`report_timezone` in [`weld/staging/settings.sql`](weld/staging/settings.sql) to the
IANA zone your sites report in. Until you do, days are UTC days.

## Layers

```
raw.salesforce_commerce_cloud.*   ELT output, untouched
  ↓
weld/staging/*.sql                3 models: order header, parsed product lines, settings
  ↓
weld/core/*.sql                   the reports: all the business logic lives here
  ↓
weld/analytics/*.sql              BI-facing contracts, deliberately thin
```

**Staging** casts and renames, reads timestamps whether they landed as TIMESTAMP or
as epoch milliseconds, and parses the product lines out of JSON. `settings.sql` has
no raw source: it is where the reporting time zone is declared.

**Core** holds the order filter and the sales equation. This is the layer worth
reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.salesforce_commerce_cloud.sales_over_time` so core
stays free to change. Both are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.salesforce_commerce_cloud.order}}` expects the model in a
`staging > salesforce_commerce_cloud` folder. Mirror that structure in your synced
repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `order` |
| product sales over time | `order` |

Both read only `order`: the header money and the `product_items` JSON on it. The
`product`, `catalog` and `category` streams are not joined in, because a product's
category is per catalog and an order does not say which catalog it was sold from;
joining on product ID alone fans a line out across every catalog that carries the
product.

## What sales_over_time returns

**Which orders count.** `new`, `open` and `completed`. Dropped: `created` (not yet
placed), `failed`, `cancelled` and `replaced`. A replaced order has a successor
order that carries the sale, so keeping both would count it twice. `status`,
`payment_status` and `shipping_status` are passed through.

**The sales equation**, in the site's own tax basis, as Business Manager shows it:
`gross_sales` (lines before any promotion), `item_discounts`, `order_discounts`
(both negative), `net_sales` (Commerce Cloud's `product_total`), `shipping`,
`taxes` and `total_sales` (Commerce Cloud's `order_total`).

**Gross and net taxation.** A site set to gross taxation prices tax-inclusive, so
its `net_sales` contains tax; a net-taxation site adds tax on top.
`prices_include_tax` says which, and `net_sales_ex_tax`, `shipping_ex_tax` and
`total_sales_ex_tax` are comparable across both. Use the `_ex_tax` columns when you
report across sites.

**Dimensions.** `site_id`, `currency`, `customer_id`, `is_guest`,
`billing_country_code`, `customer_locale`. `orders` is 1 per row, for counting.

`product_sales_over_time` carries the same equation per line. Commerce Cloud
allocates order-level promotions to lines itself (`price_after_order_discount`), so
product `net_sales` sums to order `net_sales` without an allocation of our own.

## Schema notes

- **Order dates can be timestamps or integers.** `creation_date`, `place_date` and
  `last_modified` are millisecond timestamps; the ERD shows them as integers, and
  depending on the destination they can land either way. Staging accepts both.
- **`customer_info_customer_no` can arrive typed as a timestamp.** It holds the
  customer number, and the ERD shows an integer. It is not used here. `customer_info_customer_id` is used as the customer key instead.
- **Custom attributes** (`c_*` columns) are added per instance from your own
  Commerce Cloud configuration and are not referenced. Add the ones you need to
  `staging/order.sql`.

## Notes

- **One instance, many sites.** The connector syncs every configured site into the
  same `order` table, with `site_id` on each row. `order_no` is the stream's key.
- **Multi-instance ready.** Every staging model emits an `sfcc_instance` label, and
  it is part of every join key and of the grain in core. To add an instance,
  `UNION ALL` a second block in each staging model with a different label, add a
  row to `settings.sql`, and change nothing else.
- **Bonus products** (free gifts from a promotion) arrive as lines priced at zero
  and are flagged `is_bonus_item`. They add quantity, not revenue.

[B2C Commerce API: Orders](https://developer.salesforce.com/docs/commerce/commerce-api/references/orders)
