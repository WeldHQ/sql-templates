# Salesforce Commerce Cloud dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                              one source, one instance
models/staging/stg_salesforce_commerce_cloud__order.sql                 order header
models/staging/stg_salesforce_commerce_cloud__order_product_item.sql    product lines parsed from JSON
models/staging/stg_salesforce_commerce_cloud__settings.sql              static: reporting time zone
models/core/core_salesforce_commerce_cloud__sales_over_time.sql         the sales equation per order
models/core/core_salesforce_commerce_cloud__product_sales_over_time.sql the same per product line
models/analytics/analytics__salesforce_commerce_cloud_*.sql             thin BI-facing contracts
tests/assert_salesforce_commerce_cloud__product_lines_parse.sql                                    parsed lines add up to product_sub_total
tests/assert_salesforce_commerce_cloud__product_reconciles_to_sales.sql                            product level sums to order level
tests/assert_salesforce_commerce_cloud__no_duplicate_orders.sql                                    one row per order
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
tables.

**Your time zone.** Set `report_timezone` in
`stg_salesforce_commerce_cloud__settings.sql`.

## Notes

- **Run `assert_salesforce_commerce_cloud__product_lines_parse` first.** It is the check that the JSON key
  paths match your payload. If it fails on every order, fix the paths in
  `stg_salesforce_commerce_cloud__order_product_item.sql` before reading any
  product numbers.
- **Materialise `stg_salesforce_commerce_cloud__order_product_item` as a table** on
  large instances: as a view, every query re-parses the JSON.
- **No returns.** The connector syncs none, so neither model has return rows.
- **Not run end to end.** Reconcile a closed month against Business Manager before
  relying on the output.
