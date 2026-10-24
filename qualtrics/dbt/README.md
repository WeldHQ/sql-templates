# Qualtrics dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                               one source, one Qualtrics account
models/staging/stg_qualtrics__*.sql                      6 thin wrappers over the raw tables
models/core/core_qualtrics__response_volume.sql          recorded responses per survey per day
models/core/core_qualtrics__answer_detail.sql            every answer, long format
models/core/core_qualtrics__nps_by_month.sql             NPS per question per month
models/core/core_qualtrics__distribution_performance.sql email funnel per distribution
models/analytics/analytics__qualtrics_*.sql              thin BI-facing contracts
tests/assert_qualtrics__response_volume_reconciles.sql              the series counts every response once
tests/assert_qualtrics__nps_buckets_cover_every_answer.sql          buckets add up, no scores outside 0 to 10
tests/assert_qualtrics__distribution_funnel_is_monotonic.sql        finished <= started, opened <= sent
tests/assert_qualtrics__response_channels_add_up.sql               channel columns add up to responses
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Qualtrics tables.

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `SAFE_CAST` and
  `QUALIFY` need swapping for other engines.
- **`core_qualtrics__answer_detail` is worth materializing as a table.** It is the
  widest model and `core_qualtrics__nps_by_month` reads it.
- **Plain SQL, no macros.** Multi-account works by `UNION ALL` in the staging models
  with different `qualtrics_account` labels.
- **Not run end to end.** Reconcile against a survey's Results tab before relying on
  the output.
