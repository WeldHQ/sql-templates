# Workday Financial Management dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                                 one source, one tenant
models/staging/stg_workday_financial_management__*.sql                     6 thin wrappers over the raw tables
models/core/core_workday_financial_management__general_ledger.sql          posted journal lines with their accounts
models/core/core_workday_financial_management__trial_balance.sql           month-end balances per account
models/core/core_workday_financial_management__profit_and_loss_by_month.sql income statement by month
models/core/core_workday_financial_management__ar_aging.sql                open customer invoices, aged today
models/analytics/analytics__workday_financial_management_*.sql             thin BI-facing contracts
tests/assert_workday_financial_management__journals_balance.sql                                          debits equal credits per journal and company
tests/assert_workday_financial_management__trial_balance_sums_to_zero.sql                                every month's trial balance balances
tests/assert_workday_financial_management__every_line_has_a_classified_account.sql                       the account type mapping covers every posted account
tests/assert_workday_financial_management__no_missing_ledger_amounts.sql                                 no foreign-currency line without ledger amounts
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the Workday tables.

**Your account type mapping.** Workday tenants define their own ledger account
types. `stg_workday_financial_management__ledger_account` maps them to Asset,
Liability, Equity, Revenue and Expense by keyword; edit the `CASE` until
`assert_workday_financial_management__every_line_has_a_classified_account` returns no rows.

## Notes

- **Plain SQL, no macros.** Multiple tenants work by `UNION ALL` in the staging
  models with different `workday_tenant` labels.
- **Materialise the general ledger as a table.** The trial balance and the P&L
  both read it.
- **Not run end to end.** Reconcile a closed period against Workday's Trial
  Balance before relying on the output.
