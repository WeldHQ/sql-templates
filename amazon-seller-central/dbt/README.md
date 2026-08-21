# Amazon Seller Central dbt models

Drop-in model files. Not a runnable project — no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one seller account
models/staging/stg_amazon_seller__*.sql                     11 thin wrappers over the raw reports
models/core/core_amazon_seller__sales_over_time.sql          Amazon's own Business Report numbers
models/core/core_amazon_seller__product_sales_over_time.sql  the sales equation at line grain
models/core/core_amazon_seller__settlement_ledger.sql        the deposit, itemised into a P&L
models/core/core_amazon_seller__asin_profitability.sql       contribution after fees and COGS
models/core/core_amazon_seller__traffic_and_conversion.sql   traffic at ASIN grain, where Amazon measures it
models/core/core_amazon_seller__inventory_health.sql         FBA stock and days of cover
models/core/core_amazon_seller__product_sales_over_time.yml  schema tests for the three core models
models/analytics/analytics__amazon_seller_*.sql              thin BI-facing contracts
tests/assert_sales_equation_holds.sql                        net = gross + discounts + returns
tests/assert_settlement_ties_to_deposits.sql                 the ledger sums to Amazon's own deposit figure
tests/assert_product_sales_track_business_report.sql         line grain tracks Amazon's headline, month by month
tests/assert_no_duplicate_report_generations.sql             one row per date, after de-duplication
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are near-`SELECT *` by design — dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree about what the sales equation is.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Amazon tables.

**`dbt_utils`**, for the tests in
`core_amazon_seller__product_sales_over_time.yml`.

**Your COGS.** `stg_amazon_seller__sku_cost` is a stub over a Google Sheet, because
Amazon does not know what your goods cost and no template can invent it. Point it at
whatever you have and keep the column contract — `sku`, `unit_cost`, `valid_from`,
`valid_to`. Until then `contribution_margin` is NULL (deliberately, not zero) and
`contribution_after_amazon` is still useful.

That's it — no vars to set.

## Materialisation

Set in each model's `config()` rather than in `dbt_project.yml`, so the files stay
drop-in:

- `stg_amazon_seller__orders`, `__settlement` and `__sales_and_traffic_by_asin` are
  **tables**. Core reads them repeatedly, and as views the warehouse re-scans and
  re-de-duplicates raw every time.
- The four date-grain core models are **tables partitioned by `date`, monthly**.
- Analytics models are **views**.

## Notes

- **Plain SQL, no macros.** Multi-account works by `UNION ALL` in the staging models:
  add a source block per account, union the blocks with different `amazon_seller`
  labels, change nothing else. `amazon_seller` is already part of every join key and
  of the grain in core.
- **Never full-refresh the settlement stream.** Amazon deletes settlement reports
  after 89 days, so your warehouse holds the only copy of your fee history that
  exists. `dbt run --full-refresh` over the staging model is safe — it re-reads raw —
  but resetting the *Weld stream* is not, and it is unrecoverable.
- **Run `assert_settlement_ties_to_deposits` first.** It checks the ledger against a
  number Amazon computed independently and put on your bank statement, which makes it
  worth more than the rest of the suite combined. If it passes, the fee
  classification is complete.
- **`assert_product_sales_track_business_report` is a drift test, not an equality
  test.** Amazon does not document the cancellation logic behind
  `ordered_product_sales`, so a model built from order lines lands close but never
  exactly. Measure your own steady-state gap over a few closed months and tighten the
  2% threshold to just above it.
- **Not run end to end.** Reconcile a closed month against Seller Central, and a
  settlement against your bank statement, before relying on the output.

[Full walkthrough](https://weld.app/blog/amazon-seller-vendor-central-sql-reports)
