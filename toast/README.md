# Toast templates

Sales summary, product mix and labor for restaurants on Toast, built from the
order-level data of the Toast connector. BigQuery.

Weld connector: **Toast** ([docs](https://weld.app/docs/applications/toast)). If
you use the **Toast Analytics** connector instead, which syncs Toast's
pre-aggregated reporting API, see [`../toast-analytics/`](../toast-analytics/).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_summary.sql`](weld/core/sales_summary.sql) · [dbt](dbt/models/core/core_toast__sales_summary.sql) | Sales Summary | business date × restaurant × revenue center × dining option |
| [`weld/core/menu_item_sales.sql`](weld/core/menu_item_sales.sql) · [dbt](dbt/models/core/core_toast__menu_item_sales.sql) | Product Mix | business date × restaurant × menu item × sales category |
| [`weld/core/labor_by_job.sql`](weld/core/labor_by_job.sql) · [dbt](dbt/models/core/core_toast__labor_by_job.sql) | Labor Summary by job | business date × restaurant × job |
| [`weld/core/labor_vs_sales.sql`](weld/core/labor_vs_sales.sql) · [dbt](dbt/models/core/core_toast__labor_vs_sales.sql) | Labor % and sales per labor hour | business date × restaurant |

## Layers

```
raw.toast.*            ELT output, untouched
  ↓
weld/staging/*.sql     11 thin wrappers: cast, rename, keep the latest version, parse business dates
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.toast.order}}` expects the model in a `staging > toast` folder.

## Required tables

| Model | Raw tables |
|---|---|
| sales summary | `order`, `order_check`, `order_check_selection`, `order_check_applied_service_charge`, `order_check_payment`, `restaurant`, `revenue_center`, `dining_option` |
| menu item sales | `order`, `order_check`, `order_check_selection`, `sales_category` |
| labor by job | `time_entry`, `job` |
| labor vs sales | all of the above |

## How the sales numbers are built

- **Business date, not calendar date.** Toast assigns every order to the
  restaurant's trading day. Staging turns Toast's numeric business date
  (`20240115`) into a `DATE`, so late-night orders land on the same day as in
  Toast's reports.
- **Voids and deletions are excluded** at order, check and selection level. Voided
  items stay visible in `menu_item_sales` as `voided_quantity` and
  `voided_amount`.
- **Gross, discounts, net.** `gross_sales` sums each selection's pre-discount
  price and `net_sales` its price after discounts; discounts are the difference.
  Toast documents `price` as including modifiers and quantity.
  [`assert_discounts_not_negative`](dbt/tests/assert_discounts_not_negative.sql)
  catches menus where the pre-discount price does not.
- **Gift cards are deferred revenue.** Selections Toast marks as deferred are kept
  out of sales and shown as `deferred_sales`.
- **Refunds are reported, not deducted.** `net_sales` is before refunds;
  `net_sales_after_refunds` deducts item-level refunds.
- **No fan-out.** Selections, service charges and payments are each summed to the
  order before grouping.
- **A built-in cross-check.** `check_amount` is Toast's own pre-tax check total.
  It should be close to `net_sales + service_charges + gratuities`; a persistent
  gap points at a rule above that does not match your set-up.

## Labor

Cost is hours × the hourly wage on each time entry, with overtime at 1.5×. That is
the US default; Toast lets you set a different multiplier per location, so change
it in `labor_by_job` if yours differs. Salaried staff contribute hours but no cost
(`entries_without_wage` counts those entries). Jobs flagged "exclude from
reporting" in Toast are left out of `labor_vs_sales`.

## Schema notes

- **Orders are re-read when modified**, and staging keeps the latest version of
  every order, check and selection. A selection removed from an open check (as
  opposed to voided) is not deleted from the raw table.
- **Test-mode orders are dropped** in staging.
- **Config ids are scoped per restaurant.** Lookups for revenue centers, dining
  options, sales categories and jobs join on both the id and the restaurant.
- The cash, inventory, kitchen and menu tables are available but not used here.

## Reconciling

Nothing here has been run against a live warehouse. Run Toast's Sales Summary
for one restaurant and one business day and compare gross sales, discounts, net
sales and tax; compare `menu_item_sales` with the Product Mix report for the same
day. Then compare one week of labor cost with Toast's Labor Summary.

[Toast orders API](https://doc.toasttab.com/openapi/orders/overview/) ·
[order prices](https://doc.toasttab.com/doc/devguide/apiOrderPrices.html) ·
[labor API](https://doc.toasttab.com/openapi/labor/overview/)
