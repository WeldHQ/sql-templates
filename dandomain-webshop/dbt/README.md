# DanDomain Webshop dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                      one source, one shop
models/staging/stg_dandomain_webshop__*.sql                     5 thin wrappers, latest copy per row
models/core/core_dandomain_webshop__sales_over_time.sql         the sales equation per order, credit notes as returns
models/core/core_dandomain_webshop__product_sales_over_time.sql the same per order line
models/analytics/analytics__dandomain_webshop_*.sql             thin BI-facing contracts
tests/assert_dandomain_webshop__sales_equation_holds.sql                           net = gross + discounts + returns
tests/assert_dandomain_webshop__product_reconciles_to_sales.sql                    product level sums to order level
tests/assert_dandomain_webshop__no_duplicate_order_lines.sql                       one row per order line
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
DanDomain tables. Nothing else: dates are already shop-local.

## Notes

- **Plain SQL, no macros.** Multi-shop works by `UNION ALL` in the staging models
  with a different `dandomain_shop` label per block.
- **Check the line-discount assumption first.** See the main README: compare
  `net_sales` with `reported_total_deprecated` on a few discounted orders.
- **Not run end to end.** Reconcile a closed month against the shop's invoices before
  relying on the output.
