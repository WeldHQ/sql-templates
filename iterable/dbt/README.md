# Iterable dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                   one source, one Iterable project
models/staging/stg_iterable__*.sql                           7 thin wrappers over the raw tables
models/core/core_iterable__email_performance_daily.sql       email events per campaign per day
models/core/core_iterable__email_campaign_performance.sql    whole-life numbers and rates per campaign
models/analytics/analytics__iterable_*.sql                   thin BI-facing contracts
tests/assert_daily_reconciles_to_campaigns.sql               both models count the same events
tests/assert_one_row_per_campaign.sql                        campaign grain holds; event times parse
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Iterable tables. Nothing else to configure.

## Notes

- **Check the columns first.** Iterable tables have no fixed schema; the columns come
  from your data. Run the staging models once and fix any column that is named
  differently in your warehouse before building core.
- **Not run end to end.** Nothing here has been run against a warehouse. Compare a few
  campaigns with Iterable's Campaign Analytics before relying on the output.
