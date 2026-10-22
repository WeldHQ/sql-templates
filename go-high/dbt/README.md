# HighLevel dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                   one source, one HighLevel connection
models/staging/stg_go_high__*.sql                            4 thin wrappers over the raw tables
models/core/core_go_high__pipeline_snapshot.sql              deals and value per pipeline stage, now
models/core/core_go_high__opportunity_outcomes_monthly.sql   win rate and won value by created month
models/core/core_go_high__payments_daily.sql                 payments, refunds and net per day
models/analytics/analytics__go_high_*.sql                    thin BI-facing contracts
tests/assert_opportunity_counts_reconcile.sql                both opportunity models account for every deal once
tests/assert_refunds_within_amount.sql                       no refund exceeds its payment
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
HighLevel tables.

**Which payment statuses count as collected.** `core_go_high__payments_daily` keeps
status in the grain; filter it in the analytics model or your BI tool.

## Notes

- **Multi-location ready.** `location_id` is in every grain, so an agency connection that
  syncs several sub-accounts reports them side by side.
- **Not run end to end.** Nothing here has been run against a warehouse. Reconcile against
  the Opportunities board and Payments > Transactions before relying on the output.
