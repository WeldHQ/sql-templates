# DanDomain Webshop templates

Sales reporting from Weld's DanDomain Webshop connector (the hosted DanDomain shop
platform, on the same API as SmartWeb and HostedShop): the sales equation per order
and per product line, with credit notes as returns. BigQuery, the order's own
currency, VAT excluded.

Weld connector: **DanDomain Webshop**
([docs](https://weld.app/docs/applications/dandomain-webshop)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_dandomain_webshop__sales_over_time.sql) | Gross, discounts, credit notes, net, shipping and payment fees per day | day × shop × order |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_dandomain_webshop__product_sales_over_time.sql) | The same per product and variant, with purchase cost | day × shop × order × order line |

`row_type` is `SALE` for an ordinary order and `RETURN` for a credit note.

## Read this first

Nothing here has been run against a warehouse. Reconcile a closed month against the
shop's own order list and invoices before relying on it. What returns data exists
decides most of what follows:

**1. Returns exist only as credit notes.** DanDomain creates a credit note as its own
order with status 100. The connector syncs it like any other order, with its own
lines and its own date, so a credit note becomes a RETURN row on the day it was
issued. Its value is forced negative whichever sign the shop stored it with. There
is no synced link from a credit note back to the order it credits, so a return
cannot be attributed to the original sale, and return rate per product is a
same-period ratio rather than a cohort one.

**2. Gateway refunds have no date.** `order_transaction` records payment gateway
transactions, and a refund changes the original transaction's status to refunded
in place: no refund row, no refund date. `refunded_payments` shows the amount on
the original order's row, outside the sales equation. A refund made at the gateway
without a credit note is visible there and nowhere else.

**3. Everything is VAT-exclusive.** DanDomain documents order line prices and
discounts as excluding VAT, and gives shipping and payment fees only a has-VAT flag.
The VAT treatment of discount codes is not documented, so a VAT-inclusive total
would be a guess. `line_vat` passes through the VAT recorded on the lines, and
`vat_percentage` the order's rate, for anyone who wants to build one.

**4. Line discount: per unit, by assumption.** DanDomain does not document whether
an order line's `discount` is per unit or for the whole line. It is treated as per
unit, like `price`. Check one discounted line with a quantity above 1 against its
invoice. `reported_total_deprecated` (DanDomain's own, deprecated, VAT-exclusive
product total) sits next to `net_sales` for the same comparison across all orders.

## Layers

```
raw.dandomain_webshop.*   ELT output, untouched
  ↓
weld/staging/*.sql        5 thin wrappers: cast, rename, keep the latest copy of each row
  ↓
weld/core/*.sql           the reports: all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

**Staging** casts and renames, flips discount codes negative, and keeps only the
latest copy of each order, line and transaction, because orders are re-fetched every
time they change.

**Core** holds the status filter, the credit-note handling and the discount-code
allocation. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.dandomain_webshop.sales_over_time` so core stays free
to change. Both are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.dandomain_webshop.order}}` expects the model in a
`staging > dandomain_webshop` folder. Mirror that structure in your synced repo, or
adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `order`, `order_line`, `order_discount_code`, `order_transaction`, `order_status_code` |
| product sales over time | `order`, `order_line`, `order_discount_code` |

`order_line`, `order_discount_code` and `order_transaction` are synced as part of the
`order` stream.

## What sales_over_time returns

**Which orders count.** Dropped: 0 Not received, 5 Cancelled and 99 Draft. Status
100 (credit note) is a RETURN row. Everything else is a SALE, including Order
received and Processing. `status_id` and `status_title` (the shop's own name for the
status) are passed through.

**The sales equation**, VAT excluded: `gross_sales` (unit price × quantity),
`line_discounts`, `discount_code_discounts` and `returns` (all negative),
`net_sales`, `shipping`, `payment_fees` and `total_sales_ex_vat`. On a RETURN row the
credit note's whole value is in `returns` and its shipping and fees are negative.

**Gift cards.** DanDomain redeems gift cards through the same discount-code
mechanism, and the connector does not sync the flag that tells them apart, so a
redeemed gift card lands in `discount_code_discounts`. If you sell gift cards,
separate them by `title` in `staging/order_discount_code.sql`.

**Dimensions.** `currency_iso`, `site_id`, `origin`, `language_iso`, `country_code`
(shipping country, falling back to the customer's), `user_id`, `is_b2b`,
`invoice_number`. `orders` and `credit_notes` count rows.

`product_sales_over_time` carries the same equation per line. Discount codes apply to
the whole order and are spread over its lines by value, so product `net_sales` sums
to order `net_sales`. `cost_of_goods` is the buying price recorded on the line when
the order was made, times quantity.

## Schema notes

- **`date_delivered` is the creation date.** DanDomain's API documents it as the
  order's creation datetime; `date_sent` is when it was marked as sent. The order
  stream has no column called created.
- **Datetimes are shop-local.** The API returns them without a time zone and they
  are stored as given, so `DATE()` gives the shop's own day with no conversion.
- **`order.vat` is a percentage**, not an amount.
- **`order.total` is deprecated** by DanDomain and excludes VAT, shipping and fees.
  It is kept for comparison only.
- **The ERD's edges from `order_line` and `order_transaction` to
  `order_status_code`** do not hold: line and transaction statuses are their own
  codes (transactions: 0 awaiting, 1 completed, 2 cancelled, 3 refunded). Only the
  order's status joins to `order_status_code`.

## Notes

- **Multi-currency shops.** Money is in the order's `currency_iso`, on every row.
  Do not sum across currencies without converting; `currency_rate` in
  `staging.dandomain_webshop.order` is the rate recorded on the order.
- **Multi-shop ready.** Every staging model emits a `dandomain_shop` label, and it is
  part of every join key and of the grain in core. To add a shop, `UNION ALL` a
  second block in each staging model with a different label, and change nothing
  else. Order IDs are only unique within a shop.

[DanDomain Webshop API](https://webshop-help.dandomain.dk/integration-via-api/) ·
[API reference](https://api.hostedshop.io/doc/)
