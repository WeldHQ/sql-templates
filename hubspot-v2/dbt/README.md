# HubSpot dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                          one source, one portal
models/staging/stg_hubspot_v2__*.sql                11 thin wrappers over the raw tables
models/core/core_hubspot_v2__deal_pipeline.sql      every deal, classified, with owner and company
models/core/core_hubspot_v2__deal_flow_by_month.sql created, won, lost and win rate by month
models/core/core_hubspot_v2__deal_stage_history.sql time in each stage, from property history
models/core/core_hubspot_v2__deal_activity.sql      activities logged against each deal
models/core/core_hubspot_v2__rep_activity.sql       activities per owner per day
models/core/core_hubspot_v2__company_360.sql        contacts, pipeline and last touch per company
models/analytics/analytics__hubspot_v2_*.sql        thin BI-facing contracts
tests/assert_hubspot_v2__no_duplicate_deals.sql                 deal_pipeline stays at deal grain
tests/assert_hubspot_v2__company_360_reconciles_to_deals.sql    company totals add up to the pipeline
tests/assert_hubspot_v2__one_current_stage_per_deal.sql         stage history is well sequenced
tests/assert_hubspot_v2__one_row_per_stage_entry.sql            stage label lookup never fans out
tests/assert_hubspot_v2__no_duplicate_deal_activity.sql         deal_activity stays at deal grain
```

Four layers, same as the Weld side: raw → staging → core → analytics. These are the
same models as [`../weld/`](../weld/), differing only in ref syntax, because they are
generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
HubSpot tables.

That's it: no vars, no packages.

## Notes

- **Run `assert_hubspot_v2__no_duplicate_deals` first.** Every other number depends on
  deal_pipeline being one row per deal.
- **`deal_property_history` is large.** Staging keeps only the `dealstage` and
  `pipeline` changes; materialise `stg_hubspot_v2__deal_property_history` as a table
  if the raw table is slow to scan.
- **Not run end to end.** Reconcile open pipeline and a closed month of wins against
  HubSpot before relying on the output.
