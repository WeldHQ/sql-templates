# Toast Analytics templates

Daily sales KPIs, labor by job, product mix and card payouts from Toast's own
reporting API. BigQuery.

Weld connector: **Toast Analytics**
([docs](https://weld.app/docs/applications/toast-analytics)). This is a separate
connector from **Toast**: it syncs the numbers Toast has already aggregated for
its web reports, one row per restaurant and day, instead of individual orders. If
you sync orders with the Toast connector, see [`../toast/`](../toast/), which
rebuilds the same reports from order lines.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/daily_sales.sql`](weld/core/daily_sales.sql) · [dbt](dbt/models/core/core_toast_analytics__daily_sales.sql) | Sales summary KPIs, AOV, sales per labor hour | business date × restaurant |
| [`weld/core/labor_by_job.sql`](weld/core/labor_by_job.sql) · [dbt](dbt/models/core/core_toast_analytics__labor_by_job.sql) | Labor summary by job, with labor % | business date × restaurant × job |
| [`weld/core/menu_item_performance.sql`](weld/core/menu_item_performance.sql) · [dbt](dbt/models/core/core_toast_analytics__menu_item_performance.sql) | Product mix with waste and sales share | business date × restaurant × menu item |
| [`weld/core/payouts.sql`](weld/core/payouts.sql) · [dbt](dbt/models/core/core_toast_analytics__payouts.sql) | Payouts, fees and deposits | settled date × restaurant |

## Which Toast connector?

| | Toast (`../toast/`) | Toast Analytics (this folder) |
|---|---|---|
| What is synced | orders, checks, items, payments, time entries | Toast's daily report figures |
| Matches Toast's web reports | after reconciling the rules | by construction |
| Drill to a single order | yes | no |
| Card fees and payouts | no | yes |

Toast's reporting API is rate limited per day and hour, which the connector
respects, so a first sync of long history takes a while.

## Layers

```
raw.toast_analytics.*  ELT output, untouched
  ↓
weld/staging/*.sql     5 thin wrappers: cast, rename, parse text business dates
  ↓
weld/core/*.sql        the reports, all business logic
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md). With
[GitHub Sync](https://weld.app/docs/transformations/github-sync),
`{{staging.toast_analytics.aggregated_sales}}` expects the model in a
`staging > toast_analytics` folder.

## Required tables

| Model | Raw tables |
|---|---|
| daily sales | `analytics_aggregated_sales` |
| labor by job | `analytics_labor_by_job`, `analytics_labor` |
| menu item performance | `analytics_menu_by_menu_item` |
| payouts | `analytics_payout_by_settled_date` |

## Schema notes

- **Business dates are text.** Staging accepts both `yyyymmdd` and `yyyy-mm-dd`
  and casts them to `DATE`.
- **Aggregated sales are not broken down.** The raw table has revenue center,
  dining option, order source and business hour columns, but the connector
  requests the metrics without a group-by, so they are empty and the grain is
  restaurant × day.
- **Labor in `daily_sales` is hourly jobs only**, as returned by the sales metrics
  endpoint. `labor_by_job` covers every job.
- **Ratios are recomputed.** Toast's own ratios (average order value, sales per
  labor hour, labor percentage) are not used; each model divides the sums on the
  row so you can roll up correctly by summing first.
- The check, guest, payout-by-payment, menu and labor-by-employee tables are
  available but not used here. `analytics_guest_by_payment` holds card
  fingerprints; restrict access to it in your warehouse.

## Reconciling

Nothing here has been run against a live warehouse. Compare one restaurant-day of
`daily_sales` with the Sales Summary in Toast Web, and a week of `payouts` with
the Toast deposits on your bank statement.

[Toast analytics API](https://doc.toasttab.com/openapi/analytics/overview/)
