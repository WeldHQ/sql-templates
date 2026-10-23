# WooCommerce dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one store
models/staging/stg_woocommerce__*.sql                   7 thin wrappers over the raw tables
models/core/core_woocommerce__sales_over_time.sql       the Revenue report: the business logic
models/core/core_woocommerce__product_sales_over_time.sql  the same equation at product line grain
models/core/core_woocommerce__customers.sql             the Customers report
models/analytics/analytics__woocommerce_*.sql           thin BI-facing contracts
tests/assert_woocommerce__sales_equation_holds.sql                   net = gross + discounts + returns
tests/assert_woocommerce__product_discounts_tie_to_orders.sql        line coupons sum to order coupons
tests/assert_woocommerce__no_duplicate_lines.sql                     one row per product line
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
WooCommerce tables.

**Your table prefix.** The source tables are named with WordPress' default `wp_`
prefix. If your install uses another, rename the tables in `sources.yml` and in the
staging models.

No vars to set and no packages needed. The report date rule, excluded statuses and
currency are read from your store's own settings in `wp_options`.

## Notes

- **BigQuery.** `QUALIFY`, `DATETIME(ts, 'UTC')`, `REGEXP_EXTRACT_ALL`, `UNNEST`
  and `SAFE_DIVIDE` need swapping for other engines.
- **Plain SQL, no macros.** Multi-store works by `UNION ALL` in the staging models
  with a different `woocommerce_store` label per store.
- **Not run end to end.** Reconcile a month against WooCommerce Analytics → Revenue
  before relying on the output.
