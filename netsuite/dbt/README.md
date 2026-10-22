# NetSuite dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one NetSuite account
models/staging/stg_netsuite__*.sql                      7 thin wrappers over the raw tables
models/core/core_netsuite__general_ledger.sql           every GL posting, per book and subsidiary
models/core/core_netsuite__trial_balance.sql            month-end balances per account and subsidiary
models/core/core_netsuite__profit_and_loss_by_month.sql the income statement by month and account
models/core/core_netsuite__ar_ap_aging.sql              open invoices and bills, aged today
models/analytics/analytics__netsuite_*.sql              thin BI-facing contracts
tests/assert_transactions_balance.sql                   debits equal credits per transaction
tests/assert_trial_balance_sums_to_zero.sql             every subsidiary's trial balance balances
tests/assert_no_duplicate_ledger_lines.sql              one row per accounting line
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the NetSuite tables.

**The `account` record.** It comes from NetSuite's REST catalog, so check that
`acct_number`, `acct_name`, `acct_type` and `is_inactive` exist under those names
in your warehouse.

**`deletedrecord`, or not.** If your role cannot read it, make
`stg_netsuite__deleted_record` return no rows.

## Notes

- **Plain SQL, no macros.** Multiple NetSuite accounts work by `UNION ALL` in the
  staging models with different `netsuite_account` labels.
- **Materialise `core_netsuite__general_ledger` as a table.** The trial balance
  and the P&L both read it.
- **Never sum across subsidiaries** without converting: amounts are in each
  subsidiary's base currency.
- **Not run end to end.** Reconcile a closed period against NetSuite's Income
  Statement and Trial Balance before relying on the output.
