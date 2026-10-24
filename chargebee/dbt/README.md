# Chargebee dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Chargebee site
models/staging/stg_chargebee__*.sql                     7 thin wrappers over the raw tables
models/core/core_chargebee__recurring_revenue_lines.sql recurring lines, normalised to a monthly amount
models/core/core_chargebee__mrr_by_customer_month.sql   MRR and its movement per customer
models/core/core_chargebee__mrr_movements.sql           the MRR bridge by month
models/core/core_chargebee__billing_by_month.sql        invoiced, credited, paid, by month
models/analytics/analytics__chargebee_*.sql             thin BI-facing contracts
tests/assert_chargebee__mrr_movements_reconcile.sql                beginning + movements = ending, and the bridge sums to customers
tests/assert_chargebee__one_row_per_customer_month.sql             no duplicate customer months
tests/assert_chargebee__lines_tie_to_invoice_sub_total.sql         lines net of discounts = invoice sub_total
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
disagree about how MRR is calculated.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Chargebee tables.

**An FX table, if you bill in more than one currency.** Every model keeps currency
in the grain and never adds currencies together. See the main
[README](../README.md#currency).

No vars to set.

## Notes

- **Plain SQL, no macros.** Amounts are converted from minor units in staging,
  with a short list of zero-decimal currencies; extend it there if you need to.
- **`core_chargebee__mrr_by_customer_month` is the expensive one.** It range-joins
  every recurring line to every month it covers. Materialise it and
  `recurring_revenue_lines` as tables.
- **Run `assert_chargebee__lines_tie_to_invoice_sub_total` first.** MRR reads each line's
  amount net of discount as its share of revenue; this test confirms that adds up
  to what Chargebee invoiced.
- **Not run end to end.** Reconcile a closed month against Chargebee before
  relying on the output.
