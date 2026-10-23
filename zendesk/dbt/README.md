# Zendesk dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Zendesk account
models/staging/stg_zendesk__*.sql                       4 thin wrappers over the raw tables
models/core/core_zendesk__ticket_lifecycle.sql          every ticket, classified: the business logic
models/core/core_zendesk__ticket_volume_by_day.sql      created / solved / backlog per day
models/core/core_zendesk__response_times_by_month.sql   reply and resolution times, CSAT
models/core/core_zendesk__agent_performance_by_month.sql the same per agent
models/analytics/analytics__zendesk_*.sql               thin BI-facing contracts
tests/assert_backlog_ties_to_unsolved.sql               last day of backlog = unsolved now
tests/assert_no_duplicate_tickets.sql                   one row per ticket
tests/assert_monthly_solved_reconciles.sql              daily and monthly solved counts agree
tests/assert_touch_buckets_are_exclusive.sql            one, two and multi-touch never overlap
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design, so dashboards bind to them and core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Zendesk tables.

**Your time zone.** Set `reporting_timezone` in `stg_zendesk__ticket.sql`. It is
`UTC` until you do, and Zendesk reports in the account's own zone.

No vars, no packages: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `APPROX_QUANTILES`, `JSON_VALUE`, `COUNTIF`,
  `SAFE_DIVIDE` and `QUALIFY` need swapping for other engines.
- **Materialise `core_zendesk__ticket_lifecycle` as a table.** The three other core
  models and its analytics contract all read it.
- **Plain SQL, no macros.** Multi-account works by `UNION ALL` in the staging
  models with different `zendesk_account` labels.
- **Not run end to end.** Reconcile the unsolved count and one month of solved
  tickets against Zendesk before relying on the output.
