# Recurly dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                             one source, one Recurly site
models/staging/stg_recurly__*.sql                      4 thin wrappers over the raw tables
models/core/core_recurly__recurring_revenue_lines.sql  recurring lines, normalised to a monthly amount
models/core/core_recurly__mrr_by_customer_month.sql    MRR and its movement per account
models/core/core_recurly__mrr_movements.sql            the MRR bridge by month
models/core/core_recurly__billing_by_month.sql         charge and credit invoices, by month
models/core/core_recurly__subscription_churn.sql       expired subscriptions, by churn reason
models/analytics/analytics__recurly_*.sql              thin BI-facing contracts
tests/assert_recurly__mrr_movements_reconcile.sql               beginning + movements = ending, and the bridge sums to accounts
tests/assert_recurly__one_row_per_customer_month.sql            no duplicate account months
tests/assert_recurly__credit_invoices_are_not_positive.sql      credits negative, charges positive
tests/assert_recurly__one_row_per_churned_subscription.sql      no duplicate subscriptions in churn
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
disagree about how MRR is calculated.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Recurly tables.

**An FX table, if you bill in more than one currency.** Every model keeps currency
in the grain and never adds currencies together. See the main
[README](../README.md#currency).

No vars to set.

## Notes

- **Plain SQL, no macros.** Amounts arrive in major units as 32-bit floats and
  are rounded to 2 decimals in staging.
- **`core_recurly__mrr_by_customer_month` is the expensive one.** It range-joins
  every recurring line to every month it covers. Materialise it and
  `recurring_revenue_lines` as tables.
- **Run `assert_recurly__credit_invoices_are_not_positive` first.** Netting credits
  against charges depends on Recurly's sign convention.
- **Not run end to end.** Reconcile a closed month against Recurly before relying
  on the output.
