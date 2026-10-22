# Netvisor dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one Netvisor company
models/staging/stg_netvisor__voucher_lines.sql            accounting ledger unnested to one row per line
models/staging/stg_netvisor__purchase_invoices.sql        purchase invoices with open amount
models/staging/stg_netvisor__finnish_account_groups.sql   static account-range map, edit to fit your chart
models/core/core_netvisor__general_ledger.sql             valid voucher lines with report line
models/core/core_netvisor__trial_balance_by_month.sql     opening, movement, closing per month and account
models/core/core_netvisor__profit_and_loss_by_month.sql   income statement by month, credit positive
models/core/core_netvisor__payables_aging.sql             open purchase invoices by days past due
models/analytics/analytics__netvisor_*.sql                thin BI-facing contracts
tests/assert_every_voucher_balances.sql                   line sums of every valid voucher net to zero
tests/assert_trial_balance_movements_tie_to_ledger.sql    the monthly trial balance carries the ledger exactly
```

Same models as [`../weld/`](../weld/), differing only in ref syntax, because they are
generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml`.

**Your account ranges.** `stg_netvisor__finnish_account_groups` uses a common Finnish
layout; Netvisor charts are company specific, so check it against yours.

**Your fiscal year start**, if not January: `fiscal_year_start_month` at the top of
`core_netvisor__trial_balance_by_month`.

## Notes

- **Plain SQL, no macros.**
- **Balance sheet balances need an opening position.** See the main README: the default
  sync starts in 2022, so earlier history is not in the ledger.
- **Not run end to end.** Reconcile a closed month against Netvisor's Pääkirja and
  Tuloslaskelma before relying on the output.
