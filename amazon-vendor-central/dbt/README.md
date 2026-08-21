# Amazon Vendor Central dbt models

Drop-in model files. Not a runnable project — no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one vendor group
models/staging/stg_amazon_vendor__*.sql                     6 thin wrappers over the raw reports
models/core/core_amazon_vendor__sales_over_time.sql          shipped_cogs (yours) vs shipped_revenue (Amazon's)
models/core/core_amazon_vendor__sales_by_asin.sql            sales + traffic + margin, joined
models/core/core_amazon_vendor__inventory_health.sql         the vendor scorecard, against your velocity
models/core/core_amazon_vendor__forecast_vs_actuals.sql      Amazon's forecast, scored
models/core/core_amazon_vendor__sales_over_time.yml          schema tests for the three core models
models/analytics/analytics__amazon_vendor_*.sql              BI contracts - the view filter lives here
tests/assert_no_duplicate_report_generations.sql             one row per date x ASIN x view x program
tests/assert_distributor_views_are_not_summed.sql            measures the MANUFACTURING/SOURCING overlap
tests/assert_cogs_does_not_exceed_retail.sql                 catches shipped_cogs/shipped_revenue swapped
tests/assert_traffic_is_not_multiplied_by_views.sql          glance views not inflated by the join
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Amazon tables.

**`dbt_utils`**, for the tests in `core_amazon_vendor__sales_over_time.yml`.

**A decision about `distributor_view`.** The analytics models pin
`MANUFACTURING + RETAIL`. If your business is genuinely a SOURCING or BUSINESS story,
change it there — in one place — and add a second analytics model rather than removing
the filter if you need both. Removing it lets a dashboard sum overlapping variants,
which for most vendors roughly doubles revenue.

That's it — no vars to set.

## Materialisation

- `stg_amazon_vendor__sales` is a **table**. Three core models read it, two of them
  with a 30-day window function, and as a view the warehouse re-scans and
  re-de-duplicates raw every time.
- `core_amazon_vendor__sales_by_asin` and `__inventory_health` are **tables
  partitioned by `date`, monthly**; the other two are plain tables.
- Analytics models are **views**.

## Notes

- **Plain SQL, no macros.** Multiple vendor groups work by `UNION ALL` in the staging
  models with different `amazon_vendor` labels. It is part of every join key and of
  the grain in core.
- **Enable history tables on `vendor_forecasting_report` before you need them.**
  Amazon retains only the current forecast generation, so forecast accuracy cannot be
  measured retroactively — and cannot be backfilled. The same applies to any
  point-in-time inventory question.
- **`assert_distributor_views_are_not_summed` is informational.** It cannot inspect a
  dashboard; it measures how much your MANUFACTURING and SOURCING sets overlap, so a
  failure tells you the size of the error you would be making. That is a finding, not
  a defect.
- **These models assume DAY-period report streams.** At WEEK/MONTH/QUARTER/YEAR
  granularity `start_date` and `end_date` are a range, and staging's collapse to a
  single `date` silently relabels a period as a day.
- **Not run end to end.** Reconcile a closed month of `shipped_cogs` against a Vendor
  Central export before relying on the output — and check you are reading
  `shipped_cogs`, not `shipped_revenue`.

[Full walkthrough](https://weld.app/blog/amazon-seller-vendor-central-sql-reports)
