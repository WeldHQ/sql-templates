# ChartMogul templates

Rebuilds ChartMogul's MRR movements chart and its key metrics in your warehouse.
BigQuery, ChartMogul account currency.

Weld connector: **ChartMogul**
([docs](https://weld.app/docs/applications/chartmogul)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/mrr_movements.sql`](weld/core/mrr_movements.sql) · [dbt](dbt/models/core/core_chartmogul__mrr_movements.sql) | "MRR movements": the monthly bridge from opening to closing MRR | month × currency |
| [`weld/core/customer_mrr_movements.sql`](weld/core/customer_mrr_movements.sql) · [dbt](dbt/models/core/core_chartmogul__customer_mrr_movements.sql) | The same movements per customer, for drill-down | month × customer × currency |
| [`weld/core/plan_metrics.sql`](weld/core/plan_metrics.sql) · [dbt](dbt/models/core/core_chartmogul__plan_metrics.sql) | "All key metrics", filtered by plan: MRR, ARR, ARPA, ASP, customers, churn rates, LTV | day × plan |

## ChartMogul already did the hard part

ChartMogul classifies every change in a customer's MRR as one of five activity types
and publishes them through its Activities API: `new_biz`, `expansion`, `contraction`,
`churn` and `reactivation`. Each activity carries a signed `activity-mrr-movement`.
These templates model those activities as they are. They do not re-derive movements
from subscriptions, because ChartMogul's own rules (trials, past-due customers, plan
changes inside a month, currency conversion, churn recognition settings) cannot be
reproduced faithfully from the synced tables, and a re-derivation would disagree with
the ChartMogul UI.

So the bridge is:

```
opening_mrr
  + new_business_mrr + expansion_mrr + reactivation_mrr
  + contraction_mrr + churned_mrr          (both negative)
  + other_mrr                              (unknown activity types, normally 0)
= closing_mrr
```

`net_mrr_movement` is the sum of the movement columns, and `closing_mrr` is the
running sum of `net_mrr_movement` since the first activity. Contraction and churn are
stored negative, as ChartMogul sends them, so every column adds.

## Units and currency

- **ChartMogul sends money as integer cents.** Every MRR, ARR, ARPA, ASP and LTV
  value from the API is a whole number of cents (`30000` is 300.00). Staging divides
  by 100, so every amount in staging, core and analytics is in **major units**.
- **One currency: your ChartMogul account currency.** ChartMogul converts every
  subscription into the currency set on the ChartMogul account before it computes
  activities and metrics. A multi-currency business does not need to convert
  anything here, and should not: the conversion has already happened at ChartMogul's
  rates. `currency` is still part of the movement grain as a guard, and in practice
  holds a single value.
- **Churn rates are percentages**, not fractions: `2.5` means 2.5%.

## Layers

```
raw.chartmogul.*          ELT output, untouched
  ↓
weld/staging/*.sql        4 thin wrappers: cast, rename, cents to major units, de-duplicate
  ↓
weld/core/*.sql           the reports: all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` over core. Dashboards bind to them so core can change
without breaking anything downstream.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync), Weld references
map to folder paths, so `{{staging.chartmogul.customer_activities}}` expects the model
in a `staging > chartmogul` folder.

## Required tables

| Model | Raw tables |
|---|---|
| mrr movements | `customer_activities`, `customers`, `all_metrics` |
| customer mrr movements | `customer_activities`, `customers` |
| plan metrics | `all_metrics`, `plans` |

`subscriptions` is synced by the connector but not used: it holds each
subscription's current MRR, which the activity log already covers historically.

## Notes

- **Closing MRR needs the full activity history.** The first sync of
  `customer_activities` pulls every activity, so `closing_mrr` should equal real MRR.
  `chartmogul_reported_mrr` sits next to it: ChartMogul's own MRR on the last synced
  day of the month, summed across plans from `all_metrics`. If the two drift apart,
  ChartMogul has usually restated history (for example after a billing system
  re-import). Resync `customer_activities` and `all_metrics` from scratch.
- **`all_metrics` is not refreshed backwards.** Each sync requests from the previous
  sync's date onwards, so older days keep the values they had when first synced.
- **Months are UTC calendar months** of the activity timestamp. ChartMogul's UI uses
  the account timezone, so activities close to midnight on the last day of a month
  can land in a different month than in the UI.
- **Customer counts.** `new_customers`, `churned_customers` and
  `reactivated_customers` count customers with at least one activity of that type in
  the month. `customers` in `plan_metrics` does not add up across plans: a customer
  on two plans appears under both.
- **Ratios do not average.** ARPA, ASP, LTV and churn rates in `plan_metrics` are per
  plan. For an account-wide figure, recompute from summed MRR and a distinct customer
  count rather than averaging the column.

## Schema notes

- `customer_activities`: the ERD marks `id` as the primary key; the connector merges
  on `uuid`, which is ChartMogul's stable activity identifier. Staging de-duplicates
  on `uuid`.
- Columns the ERD lists as `date` (`customer_activities.date`, `all_metrics.date`,
  the customer timestamps) are loaded as timestamps; staging casts them explicitly.

## Reconciling

Nothing here has been run against a warehouse. Before relying on the output,
reconcile one or two months against ChartMogul: the MRR movements breakdown in the
MRR report should match `mrr_movements` month for month, and the MRR on a given day
should match `plan_metrics` summed across plans. The dbt tests check internal
consistency only.

ChartMogul references:
[Activities API](https://dev.chartmogul.com/reference/list-activities) ·
[All key metrics API](https://dev.chartmogul.com/reference/retrieve-all-key-metrics) ·
[Understanding MRR movements](https://help.chartmogul.com/hc/en-us/articles/4416682609426)
