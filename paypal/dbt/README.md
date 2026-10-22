# PayPal dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source
models/staging/stg_paypal__*.sql                        2 thin wrappers
models/core/core_paypal__transactions.sql               classified transaction ledger
models/core/core_paypal__daily_balance_activity.sql     daily settlement summary per currency
models/core/core_paypal__balance_reconciliation.sql     today's balance against the history
models/analytics/analytics__paypal_*.sql                thin BI-facing contracts
tests/assert_daily_columns_sum_to_net.sql               summary columns add up to net change
tests/assert_daily_ties_to_transactions.sql             summary carries every balance-affecting record
tests/assert_transaction_grain_is_unique.sql            one row per transaction id and event code
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
PayPal tables. No vars, no packages.

## Notes

- Amounts are in major units, signed from your side, per currency. Nothing is
  converted.
- Not run end to end. Reconcile a month against PayPal's activity download before
  relying on the output.
