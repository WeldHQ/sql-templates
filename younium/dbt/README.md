# Younium dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                 one source
models/staging/stg_younium__*.sql                          3 thin wrappers
models/core/core_younium__mrr_movements.sql                monthly CMRR bridge, base currency
models/core/core_younium__subscription_mrr_movements.sql   the bridge per subscription
models/core/core_younium__account_cmrr.sql                 current CMRR per account
models/analytics/analytics__younium_*.sql                  thin BI-facing contracts
tests/assert_subscription_movements_sum_to_bridge.sql      drill-down sums to the bridge
tests/assert_movement_signs_match_classification.sql       churn and contraction negative, the rest positive
tests/assert_one_row_per_subscription_month.sql            unique grain
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Younium tables. No vars, no packages.

## Notes

- Amounts are in major units. The bridge uses the Younium base currency.
- Run `assert_movement_signs_match_classification` first: the bridge assumes
  bookings are signed CMRR changes.
- Not run end to end. Reconcile a month against Younium's bookings before relying on
  the output.
