# Amazon Seller Central templates

Rebuilds Amazon's Business Reports in your warehouse, then goes past them: what
Amazon actually paid you, and what each ASIN is worth after fees. BigQuery.

Weld connector: **Amazon Selling Partner**
([docs](https://weld.app/docs/applications/amazon-selling-partner)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/sales_over_time.sql`](weld/core/sales_over_time.sql) · [dbt](dbt/models/core/core_amazon_seller__sales_over_time.sql) | "Sales and Traffic by date" | day × seller × marketplace |
| [`weld/core/product_sales_over_time.sql`](weld/core/product_sales_over_time.sql) · [dbt](dbt/models/core/core_amazon_seller__product_sales_over_time.sql) | — (event-grain sales equation) | day × marketplace × ASIN × SKU × row type |
| [`weld/core/settlement_ledger.sql`](weld/core/settlement_ledger.sql) · [dbt](dbt/models/core/core_amazon_seller__settlement_ledger.sql) | the deposit, itemised | settlement date × order × SKU |
| [`weld/core/asin_profitability.sql`](weld/core/asin_profitability.sql) · [dbt](dbt/models/core/core_amazon_seller__asin_profitability.sql) | — (contribution after fees and COGS) | day × marketplace × ASIN × SKU |
| [`weld/core/traffic_and_conversion.sql`](weld/core/traffic_and_conversion.sql) · [dbt](dbt/models/core/core_amazon_seller__traffic_and_conversion.sql) | "Sales and Traffic by ASIN" | day × marketplace × child ASIN |
| [`weld/core/inventory_health.sql`](weld/core/inventory_health.sql) · [dbt](dbt/models/core/core_amazon_seller__inventory_health.sql) | FBA inventory + cover | seller × marketplace × SKU (point in time) |

## Related packages

Two dbt packages already cover Seller Central, and if one fits your stack, use it:

- **[fivetran/dbt_amazon_selling_partner](https://github.com/fivetran/dbt_amazon_selling_partner)** — maintained, well documented, the right answer on Fivetran. Models the API object tables (orders, order items, catalog, FBA inventory) into three enriched models. Does not read the settlement report, the Business Reports or returns, and states that it is not compatible with Vendor Central modules.
- **[Saras-Daton/AmazonSellerCentral](https://github.com/Saras-Daton/AmazonSellerCentral)** — a unification layer for Saras Analytics' Daton connector: one model per raw report, with consolidation, de-duplication and optional currency/timezone conversion. Wider source coverage, but the output is flattened raw tables rather than reports. Last updated January 2024.

These templates differ in going past the loading problem: the settlement report classified into a P&L that ties to the deposit, returns on the return date, contribution per ASIN, and Vendor Central — none of which either package covers.

## The three revenue numbers

Amazon will give you three different answers to "what did we sell", and all three are
correct. Most reporting arguments on Amazon are two people quoting different ones.

| | What it is | Dated by | Where |
|---|---|---|---|
| **Ordered product sales** | What customers ordered. The Seller Central headline. | order date | `sales_over_time` |
| **Shipped product sales** | What actually left the warehouse. | ship date | `sales_over_time` |
| **Net proceeds** | What Amazon paid you, after every fee. | settlement date | `settlement_ledger` |

They are demand, fulfilment and cash. The gap between the first and the third is
typically **25–45% of gross**, it is not a flat percentage, and it is invisible in
every sales report Amazon publishes. That gap is what `settlement_ledger` and
`asin_profitability` exist to make visible.

## Layers

```
raw.amazon_seller_central.*   ELT output, untouched
  ↓
weld/staging/*.sql            12 thin wrappers: cast, rename, de-duplicate, fix signs
  ↓
weld/core/*.sql               the reports - all the business logic lives here
  ↓
weld/analytics/*.sql          BI-facing contracts, deliberately thin
```

**Staging** does the dull work once — cast types, rename, normalise signs, and above
all **de-duplicate report generations** — so core holds only reporting logic.

**Core** is where the sales equation, the fee classification and the profitability
join live. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Dashboards, scheduled
reports and reverse-ETL syncs bind to `analytics.amazon_seller.sales_over_time`, so
core can be renamed, re-grained or split without breaking anything downstream. Most
are `SELECT *` — that is the point, not an oversight.

`dbt/` holds the same models with dbt refs. They are generated from the Weld
versions, so the two dialects cannot disagree about the logic — see
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.amazon_seller.orders}}` expects the model in a
`staging > amazon_seller` folder — mirror that structure in your synced repo, or
adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| sales over time | `sales_and_traffic_report_by_date` |
| product sales over time | `orders_by_last_updated_date_report`, `returns_by_return_date_report`, `fba_returns_report`, `merchant_listings_report` |
| settlement ledger | `settlement_report`, `settlement_description` |
| asin profitability | the above, plus `fba_reimbursements_report` and your own COGS |
| traffic and conversion | `sales_and_traffic_report_by_asin_sku`, `merchant_listings_report` |
| inventory health | `fba_inventory_summary`, `merchant_listings_report` |

Plus `weld/staging/marketplace.sql` — a static domain-to-`marketplace_id` map with no raw
source. Amazon names the marketplace three different ways across these reports
(`marketplace_id`, `sales_channel`, `marketplace_name`) and the values do not overlap;
everything here keys on the ID, and the two name-based reports are resolved through
that map in staging.

## Four things that will bite you

**1. Report generations duplicate.** Amazon re-generates the Business Reports on every
sync and restates the trailing ~72 hours as cancellations settle. Weld appends each
generation, so a single date legitimately appears several times with different
numbers. Sum the raw table and recent days are inflated by however many times they
have been re-fetched — and the multiple grows the more often you sync. Every staging
model over a report keeps only the latest generation per key. This is the most common
cause of "our Amazon revenue is 3× too high", and
[`tests/assert_no_duplicate_report_generations.sql`](dbt/tests/assert_no_duplicate_report_generations.sql)
guards it.

**2. The three ASIN reports are the same report.** `sales_and_traffic_report_by_asin`,
`..._by_asin_child` and `..._by_asin_sku` have identical column lists — including
`parent_asin`, `child_asin` and `sku` in all three — which makes them look
interchangeable. They are the same sales at parent, child and SKU granularity. Union
or join two of them and you double-count. Only the SKU one is used here.

**3. Traffic is measured on ASINs, not SKUs.** Sessions and page views belong to a
detail page, and a detail page belongs to a child ASIN. In the SKU-grain report Amazon
repeats the *same* session count on every SKU sharing that ASIN, so `SUM(sessions)`
over SKUs over-counts and every conversion rate computed from it is understated by
exactly that factor. `traffic_and_conversion` rolls traffic up with `MAX` per ASIN and
units with `SUM`, then divides — in that order.

**4. Settlement data is deleted after 89 days.** Amazon does not retain settlement
reports beyond that, and Weld cannot re-fetch what Amazon has deleted. Once synced,
your warehouse holds **the only copy of your fee history that exists**. Materialise
the settlement models as tables rather than views, and never full-refresh that
stream — a reset is unrecoverable.

## Returns land on the return date

Two return reports, two channels, deliberately not unioned in staging:

- `returns_by_return_date_report` — seller-fulfilled (MFN). Carries the **refunded
  amount**, plus label cost and SAFE-T reimbursements.
- `fba_returns_report` — FBA. Carries **units and condition, no money at all**;
  Amazon leaves the refund in the settlement report.

So MFN returns reverse value directly, and FBA returns reverse *quantity* and value it
at the SKU's average realised price — an explicit estimate rather than a silent zero.
`detailed_disposition` is the column that matters: a `SELLABLE` unit goes back on the
shelf and you lost only the fees, anything else and the COGS is gone too. That
distinction typically moves true return cost by a factor of two or three.

Returns are attributed to the day the refund happened, never back to the original
order. `avg_days_to_return` keeps the lag as a metric, which is what the order date is
actually good for.

## COGS is the one model you have to write

[`weld/staging/sku_cost.sql`](weld/staging/sku_cost.sql) is a stub, and no template
can fill it: Amazon knows what it charged you in fees and has no idea what your goods
cost. Point it at a Google Sheet, your ERP, or PO receipts — the contract is
`amazon_seller`, `sku`, `unit_cost`, `valid_from`, `valid_to`.

**The validity window is the point.** It makes cost point-in-time, so a January order
is valued at January's cost. Flat current cost silently restates last year's margin
every time a supplier price changes. Until this model returns real numbers,
`asin_profitability.contribution_after_amazon` is still useful — that is why it is a
separate column from `contribution_margin`, which is NULL without cost data rather
than zero.

## Notes

- **Never read a single day of `asin_profitability`.** Sales are dated on the order,
  fees on the settlement days or weeks later, returns later still. Each column keeps
  its own honest date, which means contribution is only meaningful aggregated over a
  window long enough to contain both a sale and its settlement — a month, in practice.
  `is_trailing_adjustment` flags the rows that make this obvious.
- **Amazon signs the settlement report; leave it alone.** Revenue positive, fees and
  refunds negative. `net_proceeds` is a plain `SUM(amount)`, and that is the only
  reason it ties to the deposit. An `ABS()` anywhere in the chain breaks the identity
  that [`assert_settlement_ties_to_deposits.sql`](dbt/tests/assert_settlement_ties_to_deposits.sql)
  checks — and that test is worth more than the rest combined, because it validates
  against a number Amazon computed independently and put on your bank statement.
- **A refund is identified by `transaction_type`, not by a negative amount.** Fees are
  negative too. Getting this backwards counts refunds as fees, so the fee ratio looks
  excellent while margin collapses.
- **`order_line`-style current-state tables are avoided on purpose.** The API `orders`
  + `orderitems` pair describes what an order looks like *now*, which cannot reproduce
  an event-based report. `orders_by_last_updated_date_report` is used instead: one row
  per line, every money column on it, incremental on `last_updated_date`, and no PII
  so it is not access-restricted. Use the API pair only if you need buyer or address
  detail.
- **Multi-account ready.** Every staging model emits an `amazon_seller` label, and it
  is part of every join key and of the grain in core. To add a seller account or
  region, `UNION ALL` a second block in each staging model with a different label —
  and change nothing else. Order IDs are only unique *within* an account.
- **Unclassified settlement lines are surfaced, not hidden.**
  `settlement_ledger.unclassified_amounts` should be zero. Amazon adds `amount_type`
  values without notice, and when it does the money is still in `net_proceeds` but in
  no named column. Watch that column rather than trusting the buckets forever.

[How to build Amazon Seller and Vendor Central reports in SQL](https://weld.app/blog/amazon-seller-vendor-central-sql-reports)
