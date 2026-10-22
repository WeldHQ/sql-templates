# Adyen dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                           one source, one Adyen company account
models/staging/stg_adyen__settlement_detail.sql      settlement entries, signed and classified
models/staging/stg_adyen__payment_accounting.sql     payment accounting records, classified
models/core/core_adyen__settlement_batches.sql       each batch itemised and tied to its payout
models/core/core_adyen__fees_by_payment_method.sql   volume and fees per payment method per day
models/core/core_adyen__payment_lifecycle.sql        one row per payment, every step
models/core/core_adyen__authorisation_rate.sql       authorised / (authorised + refused)
models/analytics/analytics__adyen_*.sql              thin BI-facing contracts
tests/assert_batch_entries_tie_to_payout.sql         a paid-out batch sums to its payout
tests/assert_fees_reconcile_to_batches.sql           fee totals agree across the two settlement models
tests/assert_one_row_per_payment.sql                 the lifecycle model is unique per payment
```

Four layers, same as the Weld side: raw, staging, core, analytics. The models are
generated from [`../weld/`](../weld/) and differ only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Adyen tables.

**The reports.** Set the Settlement details report and the Payment accounting report
to generate automatically in the Adyen Customer Area. If your Payment accounting
report lacks optional columns used in staging (`creation_date`, `payout_date`,
`payable_batch`, `acquirer`, `store`, `shopper_reference`,
`modification_psp_reference`), remove those lines or add the columns in Adyen.

## Notes

- **Amounts are major units.** Adyen's reports use decimals in the currency's major
  unit, unlike its API. Nothing is divided by 100.
- **Run `assert_batch_entries_tie_to_payout` first.** It checks the model against
  the payout Adyen sent to your bank.
- **Not run end to end.** Reconcile a batch against the Customer Area and your bank
  statement before relying on the output.
