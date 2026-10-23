# BigCommerce dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one store
models/staging/stg_bigcommerce__*.sql                     8 thin wrappers, including the static store settings
models/core/core_bigcommerce__sales_over_time.sql         the sales equation per order, refunds on the refund date
models/core/core_bigcommerce__product_sales_over_time.sql the same equation per order line
models/analytics/analytics__bigcommerce_*.sql             thin BI-facing contracts
tests/assert_bigcommerce__sale_rows_match_bigcommerce_total.sql        total_sales = BigCommerce's total_inc_tax
tests/assert_bigcommerce__product_reconciles_to_sales.sql              product level sums to order level on SALE rows
tests/assert_bigcommerce__no_duplicate_rows_at_grain.sql               one row per day x store x order x row type
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
BigCommerce tables.

**Your time zone.** Set `report_timezone` in `stg_bigcommerce__store.sql`. The
connector does not sync the store profile, so it cannot be read from the data.

## Notes

- **Plain SQL, no macros.** Multi-store works by `UNION ALL` in the staging models
  with a different `bigcommerce_store` label per block.
- **Not run end to end.** Reconcile a closed month against the BigCommerce control
  panel before relying on the output.
