# ShipHero dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one ShipHero connection
models/staging/stg_shiphero__*.sql                        11 thin wrappers over the raw tables
models/core/core_shiphero__order_fulfillment.sql          order grain: shipped when, on time, shipping cost
models/core/core_shiphero__fulfillment_by_day.sql         throughput, label cost and SLA per warehouse per day
models/core/core_shiphero__product_returns_by_month.sql   units shipped and returned per SKU per month
models/core/core_shiphero__warehouse_productivity.sql     picks and packs per user per day
models/analytics/analytics__shiphero_*.sql                thin BI-facing contracts
tests/assert_shiphero__one_row_per_order.sql                        no fan-out in order_fulfillment
tests/assert_shiphero__daily_sla_counts_every_shipped_order.sql     daily SLA counts tie to the order model
tests/assert_shiphero__label_cost_not_negative.sql                  label cost strings parsed sensibly
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
disagree about what "on time" means.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the ShipHero tables.

No vars, no packages: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `SAFE_CAST`, `COUNTIF`, `ARRAY_AGG ... LIMIT`
  and `IS NOT DISTINCT FROM` need swapping for other engines.
- **`core_shiphero__order_fulfillment` is worth materializing as a table.**
  `fulfillment_by_day` reads it, and it aggregates four child tables.
- **Plain SQL, no macros.** Multi-connection works by `UNION ALL` in the staging
  models with a different `shiphero_account` label per block.
- **Not run end to end.** Reconcile a week against ShipHero's own reports before
  relying on the output.
