# Fortnox dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                         one source, one Fortnox company
models/staging/stg_fortnox__*.sql                  thin wrappers over the raw tables
models/staging/stg_fortnox__bas_account_groups.sql static BAS range map, edit to fit your chart
models/core/core_fortnox__general_ledger.sql       voucher rows with voucher, account and year
models/core/core_fortnox__trial_balance.sql        opening, movement, closing per year and account
models/core/core_fortnox__profit_and_loss_by_month.sql  income statement by month, credit positive
models/core/core_fortnox__receivables_aging.sql    open customer invoices by days past due
models/core/core_fortnox__payables_aging.sql       open supplier invoices by days past due
models/analytics/analytics__fortnox_*.sql          thin BI-facing contracts
tests/assert_fortnox__every_voucher_balances.sql            debits equal credits on every voucher
tests/assert_fortnox__trial_balance_ties_to_fortnox.sql     computed closing balance equals Fortnox's own
tests/assert_fortnox__general_ledger_grain_is_unique.sql    no fan-out in the ledger joins
```

Four layers, same as the Weld side: raw, staging, core, analytics. These are the same
models as [`../weld/`](../weld/), differing only in ref syntax, because they are
generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Fortnox tables.

**Your chart, if it is not BAS.** `stg_fortnox__bas_account_groups` holds the account
ranges. No vars to set otherwise.

## Notes

- **Plain SQL, no macros.**
- **Run `assert_fortnox__trial_balance_ties_to_fortnox` first.** It compares against a balance
  Fortnox computed itself, so a pass means the ledger is complete.
- **Not run end to end.** Reconcile a closed year against Saldobalans and
  Resultaträkning in Fortnox before relying on the output.
