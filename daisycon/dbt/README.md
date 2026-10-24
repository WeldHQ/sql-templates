# Daisycon dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, all advertisers
models/staging/stg_daisycon__*.sql                      5 thin wrappers over the raw tables
models/core/core_daisycon__publisher_performance.sql    advertiser x publisher, totals with rates
models/core/core_daisycon__media_performance.sql        advertiser x media, totals with rates
models/core/core_daisycon__invoices.sql                 one row per invoice, with line totals
models/core/core_daisycon__invoice_costs_monthly.sql    month x advertiser x currency x line code
models/analytics/analytics__daisycon_*.sql              thin BI-facing contracts
tests/assert_daisycon__publisher_performance_is_unique.sql        one row per advertiser and publisher
tests/assert_daisycon__invoice_lines_reconcile.sql                invoice lines add up to the invoice
tests/assert_daisycon__no_negative_activity.sql                   no negative clicks, transactions or commission
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Daisycon tables
  land.
- **Full sync mode** for the two statistics streams, as described in the
  [main README](../README.md#notes).

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Reconcile a few publishers and one month of invoices against
  Daisycon before relying on the output.
