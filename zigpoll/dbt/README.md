# Zigpoll dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                           one source, one Zigpoll account
models/staging/stg_zigpoll__*.sql                    5 thin wrappers over the raw tables
models/core/core_zigpoll__response_volume.sql        answers and respondents per poll per day
models/core/core_zigpoll__answer_detail.sql          every answer, options unnested
models/core/core_zigpoll__score_summary.sql          average rating, NPS on 0 to 10 scales
models/core/core_zigpoll__attribution_by_answer.sql  orders and revenue per answer
models/analytics/analytics__zigpoll_*.sql            thin BI-facing contracts
tests/assert_zigpoll__response_volume_reconciles.sql          the series counts every answer once
tests/assert_zigpoll__nps_buckets_cover_every_answer.sql      buckets add up on NPS slides
tests/assert_zigpoll__no_negative_order_values.sql            no negative attributed revenue
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Zigpoll tables.

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `SAFE_CAST` and
  `QUALIFY` need swapping for other engines.
- **`core_zigpoll__answer_detail` is worth materializing as a table.** Two other core
  models read it.
- **Plain SQL, no macros.** Multi-account works by `UNION ALL` in the staging models
  with different `zigpoll_account` labels.
- **Not run end to end.** Reconcile against Zigpoll's results page before relying on
  the output.
