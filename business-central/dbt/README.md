# Business Central dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                          one source, all synced companies
models/staging/stg_business_central__*.sql                          4 thin wrappers over the raw tables
models/core/core_business_central__general_ledger.sql               G/L entries with account and company
models/core/core_business_central__trial_balance_by_month.sql       opening, movement, closing per month
models/core/core_business_central__profit_and_loss_by_month.sql     income statement by month, credit positive
models/core/core_business_central__receivables_aging.sql            open sales invoices by days past due
models/analytics/analytics__business_central_*.sql                  thin BI-facing contracts
tests/assert_business_central__ledger_balances_per_month.sql                          debits equal credits per company and month
tests/assert_business_central__general_ledger_grain_is_unique.sql                     no fan-out in the ledger joins
tests/assert_business_central__trial_balance_ties_to_ledger.sql                       trial balance carries every entry
```

Same models as [`../weld/`](../weld/), differing only in ref syntax, because they are
generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml`.

**Your closing documents**, if you close fiscal years in Business Central: the
`closing_documents` CTE in `core_business_central__profit_and_loss_by_month`.

## Notes

- **Plain SQL, no macros.** Multi-company is built in: `company_id` is in every key.
- **Never sum across companies** without converting; each is in its own local currency.
- **Not run end to end.** Reconcile a closed month against the Trial Balance and Income
  Statement reports in Business Central before relying on the output.
