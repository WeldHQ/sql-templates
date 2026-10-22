# Adobe Commerce dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                 one source, one store database
models/staging/stg_adobe_commerce__store_timezone.sql      your store's time zone: edit this
models/staging/stg_adobe_commerce__*.sql                   4 thin wrappers over the raw tables
models/core/core_adobe_commerce__sales_over_time.sql       the Orders report and sales equation
models/core/core_adobe_commerce__product_sales_over_time.sql  the same equation per item, with cost
models/core/core_adobe_commerce__inventory_cover.sql       stock against 30-day rate of sale
models/analytics/analytics__adobe_commerce_*.sql           thin BI-facing contracts
tests/assert_sales_equation_holds.sql                      net = gross + discounts + returns
tests/assert_product_sales_tie_to_orders.sql               item gross sales add up to the order
tests/assert_no_duplicate_orders.sql                       one row per order
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Adobe Commerce tables, and rename the tables if your database uses a table prefix.

**Your time zone.** Set `report_timezone` in
`stg_adobe_commerce__store_timezone.sql` to the store's configured time zone. The
setting is not in the synced tables, and at UTC days will not match the admin.

No vars and no packages needed.

## Notes

- **Refunds are dated by the order.** Only the order and item tables are synced, so
  a refund reduces the day the order was placed. See the main README.
- **BigQuery.** `QUALIFY`, `DATE(ts, tz)`, `CURRENT_DATE(tz)` and `SAFE_DIVIDE` need
  swapping for other engines.
- **Not run end to end.** Reconcile a month against Reports > Sales > Orders before
  relying on the output.
