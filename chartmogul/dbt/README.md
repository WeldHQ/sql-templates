# ChartMogul dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source
models/staging/stg_chartmogul__*.sql                    4 thin wrappers, cents to major units
models/core/core_chartmogul__mrr_movements.sql          monthly MRR bridge
models/core/core_chartmogul__customer_mrr_movements.sql the bridge per customer
models/core/core_chartmogul__plan_metrics.sql           key metrics per plan per day
models/analytics/analytics__chartmogul_*.sql            thin BI-facing contracts
tests/assert_chartmogul__customer_movements_sum_to_bridge.sql       drill-down sums to the bridge
tests/assert_chartmogul__movement_signs_match_type.sql              churn and contraction negative, the rest positive
tests/assert_chartmogul__bridge_grain_is_unique.sql                 one row per month and currency
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
ChartMogul tables. No vars, no packages.

## Notes

- Amounts are in major units of the ChartMogul account currency. ChartMogul sends
  cents; staging divides by 100.
- Not run end to end. Reconcile a month against ChartMogul's MRR movements chart
  before relying on the output.
