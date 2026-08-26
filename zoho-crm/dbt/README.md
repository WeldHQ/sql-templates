# Zoho CRM dbt models

Drop-in model files. Not a runnable project — no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                        one source, one Zoho org
models/staging/stg_zoho_crm__*.sql                9 thin wrappers over the raw tables
models/core/core_zoho_crm__deal_pipeline.sql      every deal, classified - the business logic
models/core/core_zoho_crm__deal_flow_by_month.sql created / won / lost per month per rep
models/core/core_zoho_crm__rep_activity.sql       calls, meetings, tasks per rep per day
models/core/core_zoho_crm__account_360.sql        account grain: people, pipeline, notes
models/analytics/analytics__zoho_crm_*.sql        thin BI-facing contracts
tests/assert_deal_stages_are_classified.sql       closed stages hiding in open pipeline
tests/assert_owner_ids_resolve.sql                deals whose owner is not in `user`
tests/assert_call_duration_parses.sql             duration strings the regex rejected
tests/assert_no_duplicate_deals.sql               one row per deal
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design — dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree about how a deal is classified as won.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the Zoho tables.

**Your closed stages.** Zoho CRM has no `is_won` or `is_closed` field, so
`core_zoho_crm__deal_pipeline` derives won and lost from the stage *string*
(`LIKE '%won%'` / `'%lost%'`). That covers Zoho's defaults, including
`Closed-Lost to Competition`. It does not cover a custom stage named
`Contract Signed`, `Churned` or `Dead`. Run
`tests/assert_deal_stages_are_classified.sql` and add whatever it surfaces to the
`CASE` in that model — this is the one edit almost every org has to make.

No vars to set, no packages required — the tests are plain `SELECT`s, so
`dbt_utils` is not needed.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `TIMESTAMP_DIFF`
  and `REGEXP_CONTAINS` all need swapping for other engines.
- **`core_zoho_crm__deal_pipeline` is materialized as a table.** The three other
  core models plus its own analytics contract all read it; as a view the warehouse
  re-scans staging four times.
- **Plain SQL, no macros.** Multi-org works by `UNION ALL` in the staging models:
  add a source block per org, union the blocks with different `zoho_org` labels,
  and change nothing else. `zoho_org` is already part of every join key.
- **Not run end to end.** Reconcile open pipeline against Zoho's own Deals view
  before relying on the output.

[Full walkthrough](https://weld.app/blog/zoho-crm-connector-sql-reports)
