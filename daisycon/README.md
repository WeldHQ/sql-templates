# Daisycon templates

Affiliate programme reporting for Daisycon advertisers: which publishers and media
drive transactions, how many of them get approved, what that costs as a share of
revenue, and what Daisycon actually invoices. BigQuery.

Weld connector: **Daisycon** ([docs](https://weld.app/docs/applications/daisycon)).
The connector reads the advertiser side of Daisycon; publisher accounts are not
covered.

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/publisher_performance.sql`](weld/core/publisher_performance.sql) · [dbt](dbt/models/core/core_daisycon__publisher_performance.sql) | Statistics by publisher, with conversion rate, approval rate and cost of sale | advertiser × publisher (totals over the sync window) |
| [`weld/core/media_performance.sql`](weld/core/media_performance.sql) · [dbt](dbt/models/core/core_daisycon__media_performance.sql) | Statistics by media (the publisher's site or channel), same measures | advertiser × media (totals over the sync window) |
| [`weld/core/invoices.sql`](weld/core/invoices.sql) · [dbt](dbt/models/core/core_daisycon__invoices.sql) | Invoice overview, with paid, overdue and days to pay | advertiser × invoice |
| [`weld/core/invoice_costs_monthly.sql`](weld/core/invoice_costs_monthly.sql) · [dbt](dbt/models/core/core_daisycon__invoice_costs_monthly.sql) | Invoiced costs per month, split by invoice line | invoice month × advertiser × currency × line code |

## Why there is no daily ad contract

The paid ads templates in this repo share a daily column set (`date_day, account_id,
..., spend, impressions, clicks, conversions, conversion_value`). Daisycon does not
fit it honestly: there are no impressions, affiliate cost is commission that is only
final once a transaction is approved, and the statistics tables carry no date
(see below). The models here use affiliate terms instead. For a blended view, take
monthly cost from `invoice_costs_monthly`.

## Layers

```
raw.daisycon.*            ELT output, untouched
  ↓
weld/staging/*.sql        5 thin wrappers: cast, rename, parse dates, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.daisycon.advertiser}}` expects the
model in a `staging > daisycon` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| publisher performance | `advertiser_statistics_by_publisher`, `advertiser` |
| media performance | `advertiser_statistics_per_media`, `advertiser` |
| invoices | `financial_invoices`, `financial_invoice_line`, `advertiser` |
| invoice costs monthly | `financial_invoice_line`, `financial_invoices`, `advertiser` |

**Sync `advertiser_statistics_by_publisher` and `advertiser_statistics_per_media`
in full mode.** See the first note.

## Notes

- **The statistics are totals for a window, not a time series.** Each row is one
  publisher (or media) summed over a date range. After a full sync every row covers
  the same trailing window: 12 months back, or the start date set on the
  connection, to now. After an incremental sync, publishers active since the
  previous sync show totals for that shorter period only, while inactive publishers
  keep their older, longer totals. Full mode keeps every row on the same window.
- **To compare periods, snapshot.** Because each full sync replaces the window, a
  month-over-month view needs you to store a copy of these models on a schedule.
- **Transactions are counted on the transaction date** (Daisycon's default), not
  the click date, and their status keeps moving from open to approved or
  disapproved for weeks. Recent windows always look less approved than old ones.
- **Two commission figures.** Daisycon reports a "commission" and a "program
  commission" per transaction, kept here as `commission` and `program_commission`.
  Daisycon's API reference does not define the two. The usual reading is that
  program commission is the full cost to the advertiser and commission the
  publisher's share, so cost of sale uses program commission. Check one publisher
  against the Daisycon dashboard and your invoices before relying on that split.
- **Transactions versus parts.** With product-level tracking one order becomes
  several transaction parts. `transactions` counts orders, `transaction_parts` the
  parts.
- **Currency** is per row. Statistics are stored one row per advertiser and
  publisher (or media), so an advertiser that runs one programme in several
  currencies can show fewer rows than the dashboard; `assert_daisycon__publisher_performance_is_unique` and a
  comparison with the dashboard will show it.
- **Invoices are fetched by invoice date** from the previous sync onwards. Payment
  status on older invoices is not refreshed by an incremental sync, so `is_paid`
  and `is_overdue` can be stale; a periodic full sync of `financial_invoices` fixes
  that.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile clicks, transactions and commission for a few
  publishers against the Daisycon dashboard (same date range, same currency), and
  one month of invoice costs against the invoices themselves, before relying on the
  output.

## Schema notes

The public ERD and the schema Weld syncs agree for every table and column used
here.

`advertiser_statistics_per_day` is not used. Its `day` column holds the day of the
month (1 to 31), not a date, and the rows follow the same window behaviour as
above, so it cannot produce a daily series. `advertiser_statistics_by_ad` has the same window behaviour as the
publisher and media tables; it is left out to keep the set small, and a model for it
would follow `media_performance` line for line.

## Vendor docs

- [Daisycon advertiser API reference](https://docs-advertiser.daisycon.com/)
- [Daisycon API resources for advertisers](https://daisycon.com/en/developers/api/resources/advertiser-resources/)
