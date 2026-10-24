# Klarna dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                           one source, one Klarna connection
models/staging/stg_klarna__payout.sql                payouts, in major units
models/staging/stg_klarna__transaction.sql           settled transactions, with direction
models/core/core_klarna__payout_reconciliation.sql   each payout, its breakdown, the tie-out
models/core/core_klarna__daily_settlement_activity.sql  sales, returns, fees per day
models/core/core_klarna__fees_by_type.sql            fees by detailed type per month
models/analytics/analytics__klarna_*.sql             thin BI-facing contracts
tests/assert_klarna__no_duplicate_payouts.sql                one row per payout
tests/assert_klarna__transactions_belong_to_a_payout.sql     transactions whose payout was not synced
tests/assert_klarna__daily_activity_reconciles_to_ledger.sql daily report sums back to the ledger
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree about how a payout is reconciled.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Klarna tables.

**Directions for the undocumented types**, if they matter to you. `COMMISSION`,
`CORRECTION` and `REVERSAL_MERCHANT_PROTECTION` are kept out of every net figure
until you add them to the `CASE` in `stg_klarna__transaction`. See the main
[README](../README.md).

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE` and
  `IS NOT DISTINCT FROM` in join conditions need swapping for other engines.
- **Plain SQL, no macros.** Multiple Klarna connections work by `UNION ALL` in the
  staging models with different `klarna_account` labels; the label is already part
  of every join key.
- **Not run end to end.** Reconcile a month of payouts against the Klarna Merchant
  Portal before relying on the output.
