# BigCommerce templates

Sales reporting from Weld's BigCommerce connector: the sales equation per order and
per product, with refunds on the day they were issued. BigQuery, the order's own
currency.

Weld connector: **BigCommerce**
([docs](https://weld.app/docs/applications/bigcommerce)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_bigcommerce__sales_over_time.sql) | Gross, discounts, refunds, net, shipping, tax and total per day | day × store × order × row type |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_bigcommerce__product_sales_over_time.sql) | The same equation per product and SKU, with cost | day × store × order × order line × row type |

Row type is `SALE` (the order, dated when it was placed) or `RETURN` (refunds,
dated when they were issued). Aggregate to day, week or month in BI.

## Read this first

Nothing here has been run against a warehouse. Reconcile a closed month against the
BigCommerce control panel (Orders, and Analytics → Orders) before relying on it.
Four properties of the source shape what these models can say:

**1. The store's time zone is not synced.** BigCommerce timestamps are UTC and the
control panel reports in the store's time zone. Set `report_timezone` in
[`weld/staging/store.sql`](weld/staging/store.sql) to your store's IANA zone (for
example `America/New_York`). Until you do, days are UTC days and late-evening orders
land on the next day.

**2. Refunds are dated; per-product refund money is not.** The `refund` table has a
creation timestamp and a tax-inclusive total, so `sales_over_time` puts every refund
on the day it happened, and it reconciles. But BigCommerce refunds products by
quantity and does not store the money per line, so the RETURN rows in
`product_sales_over_time` value each returned unit at the line's net unit price.
That is an estimate, flagged with `is_return_value_estimated`, and product-level
returns will not sum to order-level returns. Refunds of shipping, handling or a lump
sum against the order have no product and appear only in `sales_over_time`.

Refunds made outside BigCommerce's refund flow (directly in the payment gateway, or
before a store used the refunds API) do not exist in the `refund` table. The
order's `refunded_amount` would show them, but it carries no date.

**3. `refund_line_item.product_id` is not a product ID.** It holds BigCommerce's
`item_id`, which points at the order line for PRODUCT refunds, at the shipping
address for SHIPPING and HANDLING, and at the order for ORDER refunds. Staging renames
it to `item_id` and joins it only to `order_line_item.id`.

**4. Discounts are derived, not read.** BigCommerce's `discount_amount` and
`coupon_discount` are not documented precisely enough to know whether one contains
the other, so summing them risks counting coupons twice. `discounts` is computed from
BigCommerce's own totals instead (`total_ex_tax − subtotal_ex_tax − shipping −
handling − wrapping`), which makes `total_sales` on a SALE row equal the order's
`total_inc_tax`. Both reported columns are passed through for comparison.

## Layers

```
raw.bigcommerce.*       ELT output, untouched
  ↓
weld/staging/*.sql      8 thin wrappers: cast, rename, fix signs, declare the time zone
  ↓
weld/core/*.sql         the reports: all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts and renames, flips line discounts negative, and unpicks the
misnamed refund item key. `store.sql` has no raw source: it is where the reporting
time zone is declared.

**Core** holds the order filter, the sales equation and the discount allocation.
This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.bigcommerce.sales_over_time` so core stays free to
be renamed or re-grained. Both are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions, so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.bigcommerce.order}}` expects the model in a
`staging > bigcommerce` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `order`, `refund`, `refund_line_item`, `refund_payment`, `channel` |
| product sales over time | `order`, `order_line_item`, `order_line_item_discount`, `refund`, `refund_line_item`, `refund_payment` |

`order_line_item` and `order_line_item_discount` are synced as part of the `order`
stream, and `refund_line_item` and `refund_payment` as part of `refund`.

## What sales_over_time returns

**Which orders count.** Incomplete (status 0, an abandoned checkout), Cancelled (5),
Declined (6) and archived orders are dropped. Everything else stays, including
Pending and Awaiting Payment. `status_id` and `status` are passed through so you can
narrow further in analytics. Refunds are kept only for orders that are kept, and a
refund whose every payment was declined is dropped.

**The sales equation.** `gross_sales` (products before discounts, tax excluded),
`discounts` and `returns` (both negative), `net_sales`, `shipping_charges`,
`handling_charges`, `gift_wrapping_charges`, `taxes`, `total_sales_ex_tax` and
`total_sales`. On RETURN rows, `returns` is everything refunded, tax excluded,
including any refunded shipping, and `taxes` is the refunded tax.

**Payments that are not discounts.** `gift_certificate_payments` and
`store_credit_payments` are how part of an order was paid. They stay out of the sales
equation.

**Dimensions.** `currency_code`, `channel_name` and `channel_type` (from `channel`),
`order_source`, `status`, `payment_method`, `country_code` (billing country, falling
back to the GeoIP country), `customer_id`, `is_digital`, and `order_date` on every
row, so a RETURN row can be traced back to the sale it reverses.

**Counting.** `is_order_placed` is 1 on exactly one row per order. Sum it over any
window for the order count and the average order value denominator.

## Schema notes

- **Timestamps are full timestamps.** The ERD lists `date_created`, `date_modified`,
  `date_shipped` and `refund.created` as dates; they arrive as UTC timestamps. Staging casts them to TIMESTAMP, which works either way.
- **`refund_line_item.product_id`** is BigCommerce's `item_id` under another name, as
  described above. The ERD's edge from `product` to `refund_line_item` does not
  hold for any item type, so do not join on it.
- **`refund_line_item` has one row per refund and item ID.** If one refund covered a
  PRODUCT and a SHIPPING item whose IDs happen to coincide, only one row appears.
  Rare, but it would understate `quantity_refunded` on that refund. The refund's
  money comes from `refund.total_amount`, so `returns` is unaffected.

## Notes

- **Multi-currency stores.** Every money column is in the order's `currency_code`,
  which is on every row. Do not sum across currencies without converting.
  `default_currency_code` and `store_default_to_transactional_exchange_rate` are
  available in `staging.bigcommerce.order`; check on one order which currency
  BigCommerce reports its totals in before converting.
- **`cost_of_goods`** is BigCommerce's cost price at the time of the order times
  quantity. BigCommerce stores 0 when no cost price was set, so treat zero as
  unknown.
- **Multi-store ready.** Every staging model emits a `bigcommerce_store` label, and
  it is part of every join key and of the grain in core. To add a store, `UNION ALL`
  a second block in each staging model with a different label, add a row to
  `store.sql`, and change nothing else. Order IDs are only unique within a store.

[BigCommerce order statuses](https://support.bigcommerce.com/s/article/Order-Statuses) ·
[Orders API](https://developer.bigcommerce.com/docs/rest-management/orders) ·
[Refunds API](https://docs.bigcommerce.com/developer/docs/admin/checkout-and-cart/orders/refunds)
