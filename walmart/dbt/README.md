# Walmart dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                           one source
models/staging/stg_walmart__*.sql                    7 thin wrappers over the raw tables
models/core/core_walmart__sales_over_time.sql        sales equation per order day
models/core/core_walmart__product_sales_over_time.sql  the same by SKU
models/core/core_walmart__settlement_ledger.sql      the reconciliation file as a ledger
models/analytics/analytics__walmart_*.sql            thin BI-facing contracts
tests/assert_walmart__product_reconciles_to_sales.sql         SKU level sums to day level
tests/assert_walmart__settlement_ties_to_deposits.sql         ledger sums to each deposit
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two cannot disagree
about the logic.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the Walmart tables.

**Your timezone.** Set `report_timezone` in `stg_walmart__seller.sql`. It defaults
to `UTC`.

## Notes

- **Plain SQL, no macros.** A second account is a `UNION ALL` block per staging
  model with a different `walmart_seller` label.
- **Not run end to end.** Reconcile a month against Seller Center before relying
  on the output.
