# Typeform dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                      one source, one Typeform account
models/staging/stg_typeform__*.sql              6 thin wrappers over the raw tables
models/core/core_typeform__response_volume.sql  responses per form per day
models/core/core_typeform__answer_detail.sql    every answer, choices unnested
models/core/core_typeform__score_summary.sql    NPS, average and top-two-box per question
models/analytics/analytics__typeform_*.sql      thin BI-facing contracts
tests/assert_response_volume_reconciles.sql     the series counts every response once
tests/assert_nps_buckets_cover_every_answer.sql promoters + passives + detractors = answers
tests/assert_no_duplicate_answers.sql           one row per answer x choice
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Typeform tables.

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `APPROX_QUANTILES`
  and `QUALIFY` need swapping for other engines.
- **Plain SQL, no macros.** Multi-account works by `UNION ALL` in the staging models
  with different `typeform_account` labels.
- **Only submitted responses are synced**, so there is no completion rate to build.
  See the [main README](../README.md).
- **Not run end to end.** Reconcile against Typeform's Results page before relying on
  the output.
