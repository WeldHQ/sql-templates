# Traede dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Traede account
models/staging/stg_traede__*.sql                        11 thin wrappers over the raw tables
models/core/core_traede__invoiced_sales_over_time.sql   booked invoices per day, the revenue report
models/core/core_traede__product_sales.sql              units, revenue, cost and margin per variant per day
models/core/core_traede__order_book.sql                 every order line with open quantity and value
models/core/core_traede__production_order_status.sql    inbound production, outstanding and slippage
models/analytics/analytics__traede_*.sql                thin BI-facing contracts
tests/assert_no_duplicate_order_lines.sql               one row per order line
tests/assert_product_sales_grain.sql                    no fan-out in product_sales
tests/assert_line_units_match_invoice_units.sql         line units sum to invoice header units
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
disagree about what counts as revenue.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the Traede tables.

**Your base currency.** `core_traede__product_sales` has a one-line `settings` CTE
with `'EUR'`. Set it to the currency your Traede cost prices are kept in; margin is
only computed for invoices in that currency.

No vars, no packages: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `SAFE_CAST` and `ANY_VALUE` need swapping
  for other engines.
- **Plain SQL, no macros.** Multi-account works by `UNION ALL` in the staging
  models with a different `traede_account` label per block.
- **Not run end to end.** Reconcile a month against Traede's invoice list before
  relying on the output, and remember credit notes are not synced.
