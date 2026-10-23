# Medallia dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                         one source, one Medallia instance
models/staging/stg_medallia__*.sql                 6 thin wrappers over the raw tables
models/core/core_medallia__feedback_volume.sql     invitations, responses, response rate
models/core/core_medallia__answer_detail.sql       every answer with label and score
models/core/core_medallia__nps_by_unit_month.sql   NPS per unit per month
models/core/core_medallia__topic_volume.sql        comment topics per unit per month
models/analytics/analytics__medallia_*.sql         thin BI-facing contracts
tests/assert_medallia__nps_questions_are_0_to_10.sql         the NPS question rule picked the right questions
tests/assert_medallia__feedback_volume_reconciles.sql        the series counts every response once
tests/assert_medallia__no_duplicate_answers.sql              one row per record x question x position
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Medallia tables.

**Your NPS question.** `core_medallia__nps_by_unit_month` picks questions whose name
contains "recommend". Run `tests/assert_medallia__nps_questions_are_0_to_10.sql`, then replace
the rule in the `nps_questions` CTE with your question ids.

**Your segment fields.** `stg_medallia__feedback` reads only the columns every
instance has. Add the record fields you report by.

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `SAFE_CAST` and
  `QUALIFY` need swapping for other engines.
- **`core_medallia__answer_detail` is worth materializing as a table.** It is the
  widest model and `core_medallia__nps_by_unit_month` reads it.
- **Plain SQL, no macros.** Multiple instances work by `UNION ALL` in the staging
  models with different `medallia_account` labels.
- **Not run end to end.** Reconcile against Medallia's own reports before relying on
  the output.
