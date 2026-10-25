# Salesforce dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one org
models/staging/stg_salesforce__*.sql                        8 thin wrappers over the raw tables
models/core/core_salesforce__opportunity_pipeline.sql       every opportunity, classified, with account and owner
models/core/core_salesforce__pipeline_flow_daily.sql        created, won, lost and pipeline due per day per owner
models/core/core_salesforce__opportunity_stage_history.sql  time in each stage, from OpportunityHistory
models/core/core_salesforce__lead_funnel_daily.sql          leads created and converted per day per source
models/core/core_salesforce__rep_activity.sql               calls, emails, tasks and meetings per rep per day
models/analytics/analytics__salesforce_*.sql                thin BI-facing contracts
tests/assert_salesforce__no_duplicate_opportunities.sql          opportunity_pipeline stays at opportunity grain
tests/assert_salesforce__flow_reconciles_to_pipeline.sql         daily flow adds up to the pipeline
tests/assert_salesforce__one_current_stage_per_opportunity.sql   stage history is well sequenced and current
```

Four layers, same as the Weld side: raw → staging → core → analytics. These are the
same models as [`../weld/`](../weld/), differing only in ref syntax, because they are
generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Salesforce tables.

**Your currency setting.** In a multi-currency org, swap the `NULL` currency line in
`stg_salesforce__opportunity` for the commented `currency_iso_code` line.

No vars, no packages.

## Notes

- **Run `assert_salesforce__no_duplicate_opportunities` first.** Every other number
  depends on opportunity_pipeline being one row per opportunity.
- **Materialise `core_salesforce__opportunity_pipeline` as a table.** Three core
  models and its analytics contract read it.
- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `QUALIFY` and
  `TIMESTAMP_DIFF` need swapping for other engines.
- **Not run end to end.** Reconcile open pipeline and a closed month of wins against
  Salesforce reports before relying on the output.
