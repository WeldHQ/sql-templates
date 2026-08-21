# Amazon Vendor Central templates

Rebuilds Amazon's vendor retail analytics reports in your warehouse: sales where
*Amazon* is the customer, the operational scorecard you are graded on, and Amazon's
own demand forecast against what actually shipped. BigQuery.

Weld connector: **Amazon Vendor Central**
([docs](https://weld.app/docs/applications/amazon-vendor-central)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_amazon_vendor__sales_over_time.sql) | Vendor Sales, by day | day × marketplace × view × program |
| [`weld/core/sales_by_asin.sql`](weld/core/sales_by_asin.sql) · [dbt](dbt/models/core/core_amazon_vendor__sales_by_asin.sql) | Sales + Traffic + Margin, joined | + ASIN |
| [`weld/core/inventory_health.sql`](weld/core/inventory_health.sql) · [dbt](dbt/models/core/core_amazon_vendor__inventory_health.sql) | Vendor Inventory + velocity | + ASIN |
| [`weld/core/forecast_vs_actuals.sql`](weld/core/forecast_vs_actuals.sql) · [dbt](dbt/models/core/core_amazon_vendor__forecast_vs_actuals.sql) | — (forecast scored against shipments) | forecast window × ASIN |

## Vendor Central is not Seller Central with different table names

If you have modelled Seller Central, unlearn most of it before starting here. As a
vendor you sell to Amazon and Amazon sells to the customer, and that changes the data
completely:

- **There are no orders.** No order table, no line items, nothing to aggregate up.
  Amazon reports daily aggregates per ASIN and that is all you get.
- **Your revenue is what Amazon pays you**, not what the customer pays.
- **Your revenue is `shipped_cogs`.** Amazon's field naming, not ours — it is Amazon's
  cost of goods, which is your revenue. `shipped_revenue` is what Amazon charges the
  customer: Amazon's revenue, not yours.
- **Revenue is recognised on shipment**, not on order. `ordered_revenue` is a demand
  indicator.
- **There are no fees.** Amazon buys at wholesale; the margin conversation is about
  cost price and co-op funding instead.

> **Report your top line off `shipped_cogs`.** Every vendor that has ever presented a
> suspiciously excellent Amazon quarter reported `shipped_revenue` by mistake. It is
> the single most expensive mix-up in vendor reporting, and the field names invite it.

`amazon_gross_markup_rate` puts both on one row — `(retail − wholesale) / retail`.
A sharp fall means Amazon is discounting into its own margin, which usually precedes
being asked to fund it.

## Every sales report arrives four times

Amazon generates Vendor Sales and Vendor Inventory separately for each combination of
two dimensions, and Weld lands all of them in one table:

| | Values | Meaning |
|---|---|---|
| `distributor_view` | `MANUFACTURING` | ASINs you manufacture, whoever sourced them |
| | `SOURCING` | ASINs sourced directly from your vendor group |
| `selling_program` | `RETAIL` | amazon.com consumer |
| | `BUSINESS` | Amazon Business (B2B) |

**The variants overlap.** An ASIN you both manufacture and source appears under both
views, describing the same units. Sum across them and you double-count — for most
vendors close to a clean 2×, which is exactly big enough to notice and exactly
plausible enough to believe.

So `distributor_view` and `selling_program` are part of the grain in every core model,
which forces the choice to be explicit, and the analytics models pin
`MANUFACTURING + RETAIL` — "how is my brand selling on Amazon", the right default.
[`assert_distributor_views_are_not_summed.sql`](dbt/tests/assert_distributor_views_are_not_summed.sql)
measures how much overlap your catalogue actually has, so you know the size of the
error you would be making.

**Traffic and margin are not split this way.** Glance views and Net Pure Product
Margin are reported per ASIN per day, full stop. Joined onto four-way-split sales they
repeat on up to four rows, which multiplies traffic and divides every conversion rate
by the same factor. `sales_by_asin` documents it;
[`assert_traffic_is_not_multiplied_by_views.sql`](dbt/tests/assert_traffic_is_not_multiplied_by_views.sql)
catches it.

## Layers

```
raw.amazon_vendor_central.*   ELT output, untouched
  ↓
weld/staging/*.sql            6 thin wrappers: cast, rename, de-duplicate, fix signs
  ↓
weld/core/*.sql               the reports - all the business logic lives here
  ↓
weld/analytics/*.sql          BI-facing contracts; these are where the view filter lives
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions — see
[dbt/README.md](dbt/README.md).

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `vendor_sales_report` |
| sales by asin | `vendor_sales_report`, `vendor_traffic_report`, `vendor_net_pure_product_margin_report` |
| inventory health | `vendor_inventory_report`, `vendor_sales_report` |
| forecast vs actuals | `vendor_forecasting_report`, `vendor_sales_report` |

## The scorecard is the reason to build this

The sales numbers you could get from a weekly email. These you could not, and they are
what your Vendor Manager quotes at you in a business review:

| Metric | Whose problem | Why it matters |
|---|---|---|
| `vendor_confirmation_rate` | **Yours** | Share of units Amazon ordered that you confirmed. Below ~95% and Amazon treats you as unreliable supply — and orders less. |
| `average_vendor_lead_time_days` | **Yours** | PO submission to receipt. Long lead times make Amazon carry more safety stock, which it offsets by ordering less. |
| `sell_through_rate` | Shared | Slow turns lead to smaller POs. |
| `unhealthy_inventory_units` | Amazon's, until it is yours | Excess versus forecast. Precedes a markdown request or a return-to-vendor. |
| `unfilled_customer_ordered_units` | Amazon's | Customers ordered, Amazon could not ship. Lost sales you can prove. |

`inventory_health` puts these against your own shipment velocity, which Vendor Central
will not do: 400 units of unhealthy inventory is either two weeks of cover or two
years of it, and the report alone cannot tell you which. `unhealthy_weeks_of_cover` is
the number to take into the review — "eleven weeks of cover" is a conversation, "3,400
units" is not.

## The forecast is advance notice of your next PO

Amazon's demand forecast drives Amazon's purchase orders, at four confidence levels.
`mean` is the expected value; `p70`/`p80`/`p90` are the units Amazon is 70/80/90%
confident of selling, and the spread between mean and p90 is how uncertain Amazon is.
Plan capacity against p80 or p90 — the mean is right half the time by construction.

`forecast_vs_actuals` scores elapsed windows against what shipped and reports which
confidence band the outcome landed in. If most ASINs realise below p70, Amazon is
systematically over-forecasting your catalogue and over-ordering, and the overstock
becomes your markdown request. That is a finding worth escalating — and it needs a
population, not one ASIN.

**One structural limitation.** Amazon retains only the *current* forecast, so a
realised window is scored against whatever forecast was live when you last synced —
which, for a window already past, may have been revised toward the outcome. Real
forecast accuracy needs the forecast as it stood *before* the window opened, which
means retaining generations: enable Weld history tables on the
`vendor_forecasting_report` stream and read the history table instead. **You cannot
backfill this.** Until then, treat the error columns as indicative rather than as a
KPI.

## Notes

- **Report generations duplicate.** Amazon re-generates these reports on every sync
  and restates the trailing ~72 hours. Weld appends each generation, so a date
  legitimately appears several times with different numbers. Every staging model keeps
  only the latest generation per key, and
  [`assert_no_duplicate_report_generations.sql`](dbt/tests/assert_no_duplicate_report_generations.sql)
  guards it — the failure is silent, since `shipped_cogs` stays plausible and is
  simply a multiple of the truth.
- **`net_pure_product_margin` is Amazon's margin, not yours.** It is
  `(Amazon's revenue − what Amazon paid you − co-op funding) / revenue`. Worth tracking
  anyway: it is what your Vendor Manager is measured on, and watching it fall is
  advance notice of a conversation about cost price.
- **These models assume DAY-period reports.** `start_date` and `end_date` are equal at
  DAY granularity, and staging collapses them to a single `date`. If a stream is
  configured for WEEK, MONTH, QUARTER or YEAR they are a range, and that collapse
  silently relabels a period as a day — change the grain in staging rather than
  working around it downstream.
- **Real-time reports are for watching, not for reporting.** 29-day retention, and
  Amazon documents that they disagree with the daily reports by design — they trade
  accuracy for latency and do not wait for adjustments to settle. Reconciling the two
  is not a bug to fix. `staging/real_time_sales.sql` is provided and deliberately
  feeds nothing in core.
- **Timezone.** Amazon's vendor retail analytics reports are in **PST regardless of
  marketplace**, but the real-time reports are in **UTC**. Joining an hourly series to
  a daily one without converting misaligns them by 7–8 hours, which puts an evening
  spike on the wrong day.
- **Returns are negated in staging**, so `shipped_units + customer_returns` is plain
  addition. They are reported on the return date, so a row's returns belong to earlier
  shipments — `return_rate_units` is a period ratio, not a cohort return rate.
- **Negative values are often real.** `open_purchase_order_units` goes negative when
  you over-ship against a PO; `ordered_units` in the real-time report goes negative
  when an hour has more cancellations than orders. Neither is bad data.
- **Purchase orders are not modelled here.** Weld syncs `vendor_purchase_order` and
  `vendor_purchase_order_item`, and they are the natural next models — PO acceptance
  rate, fill rate against confirmed quantities, chargeback exposure. They are left out
  because the analytics reports above answer the reporting questions first, and PO
  modelling is a different job.

[How to build Amazon Seller and Vendor Central reports in SQL](https://weld.app/blog/amazon-seller-vendor-central-sql-reports)
