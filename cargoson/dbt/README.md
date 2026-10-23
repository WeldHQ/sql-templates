# Cargoson dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Cargoson connection
models/staging/stg_cargoson__booking.sql                bookings, price as a number
models/staging/stg_cargoson__booking_row.sql            goods lines
models/core/core_cargoson__shipments.sql                one row per shipment, classified
models/core/core_cargoson__carrier_costs_by_month.sql   spend and performance per carrier per month
models/core/core_cargoson__lane_costs.sql               cost per lane and carrier
models/analytics/analytics__cargoson_*.sql              thin BI-facing contracts
tests/assert_cargoson__no_duplicate_shipments.sql                 one row per booking
tests/assert_cargoson__statuses_are_classified.sql                statuses falling through to 'open'
tests/assert_cargoson__monthly_costs_reconcile_to_shipments.sql   monthly spend sums back to shipments
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree about what a shipment cost.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Cargoson tables.

**A complete reference table.** Only the bookings whose references you list in
your own warehouse are synced. These models are only as complete as that
list. See the main [README](../README.md).

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_CAST`, `SAFE_DIVIDE` and
  `IS NOT DISTINCT FROM` in join conditions need swapping for other engines.
- **`core_cargoson__shipments` is worth materializing as a table.** Both other core
  models and its own analytics contract read it.
- **Plain SQL, no macros.** Multiple Cargoson connections work by `UNION ALL` in the
  staging models with different `cargoson_account` labels; the label is already part
  of every join key.
- **Not run end to end.** Reconcile a month of shipments and spend against Cargoson
  before relying on the output.
