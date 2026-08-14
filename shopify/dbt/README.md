# Shopify dbt models

Drop-in model files. Not a runnable project — no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                       one source, one store
models/staging/stg_shopify__*.sql                     12 thin wrappers over the raw tables
models/core/core_shopify__sales_over_time.sql         the sales report - the business logic
models/core/core_shopify__sales_over_time.yml         schema tests
models/core/core_shopify__product_sales_over_time.sql the same equation at line grain
models/core/core_shopify__sku_cost_per_day.sql        point-in-time cost per SKU
models/core/core_shopify__sales_by_product.sql        cheap product ranking
models/analytics/analytics__shopify_*.sql             thin BI-facing contracts
tests/assert_sales_equation_holds.sql                 net = gross + discounts + returns
tests/assert_product_reconciles_to_sales.sql          product level sums to order level
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design — dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree about what the sales equation is.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Shopify tables.

**`dbt_utils`**, for the tests in `core_shopify__sales_over_time.yml`.

**History tables on `inventory_item`**, if you want point-in-time COGS. Costs come
from Shopify's own `inventory_item` plus its history table, so a January order is
valued at January's cost. Without history enabled, costs fall back to the current
value and margin on old orders will be wrong.

That's it — no vars to set. The timezone comes from `shop.iana_timezone`, so the
model localises correctly without configuration.

## Notes

- **Plain SQL, no macros.** Multi-store works by `UNION ALL` in the staging models:
  add a source block per store, union the blocks with different `shopify_store`
  labels, and change nothing else. `shopify_store` is already part of every join key
  and of the grain in core.
- **`stg_shopify__order_agreement_sale` is materialized as a table.** Core
  references it repeatedly; as a view the warehouse re-scans raw every time.
- **Not run end to end.** Reconcile a month against a Shopify admin export before
  relying on the output.

[Full walkthrough](https://weld.app/blog/shopify-dbt-sales-model)
