# QuickBooks Online dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one company
models/staging/stg_quickbooks__*.sql                    6 thin wrappers over the raw tables
models/core/core_quickbooks__general_ledger.sql         every journal line, debit and credit
models/core/core_quickbooks__trial_balance.sql          month-end balances per account
models/core/core_quickbooks__profit_and_loss_by_month.sql  the P&L by month and account
models/core/core_quickbooks__ar_ap_aging.sql            open invoices and bills, aged today
models/analytics/analytics__quickbooks_*.sql            thin BI-facing contracts
tests/assert_quickbooks__transactions_balance.sql                   debits equal credits per transaction
tests/assert_quickbooks__trial_balance_sums_to_zero.sql             every month's trial balance balances
tests/assert_quickbooks__no_duplicate_ledger_lines.sql              one row per journal line
tests/assert_quickbooks__every_ledger_line_has_a_class.sql          every line's account has a class
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the QuickBooks tables. No vars to set: the fiscal year start comes from the
`company` table.

## Notes

- **Plain SQL, no macros.** Multi-company works by `UNION ALL` in the staging
  models with different `quickbooks_company` labels.
- **Materialise `core_quickbooks__general_ledger` as a table.** The trial balance
  and the P&L both read it.
- **Run `assert_quickbooks__transactions_balance` first.** It fails when the incremental sync
  has missed an edit to an older transaction; a full resync of `journal_report`
  fixes it.
- **Not run end to end.** Reconcile a closed month against the QuickBooks reports
  before relying on the output.
