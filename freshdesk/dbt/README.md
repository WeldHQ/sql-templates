# Freshdesk dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one helpdesk
models/staging/stg_freshdesk__*.sql                       5 thin wrappers over the raw tables
models/core/core_freshdesk__ticket_lifecycle.sql          every ticket with derived first response
models/core/core_freshdesk__ticket_volume_by_day.sql      created / first responded / replies per day
models/core/core_freshdesk__first_response_by_month.sql   first response time and SLA rate
models/core/core_freshdesk__agent_performance_by_month.sql per agent activity and CSAT
models/core/core_freshdesk__csat_by_month.sql             satisfaction survey results
models/analytics/analytics__freshdesk_*.sql               thin BI-facing contracts
tests/assert_freshdesk__no_duplicate_tickets.sql                     one row per ticket
tests/assert_freshdesk__first_response_after_creation.sql            no negative response times
tests/assert_freshdesk__created_reconciles.sql                       daily and monthly created counts agree
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml`.

**Your time zone.** Set `reporting_timezone` in `stg_freshdesk__ticket.sql`
(IANA name). It is `UTC` until you do.

**Your custom statuses**, if any, in the status `CASE` in the same file.

No vars, no packages.

## Notes

- **No resolution time.** The connector does not sync Freshdesk's ticket stats;
  see the [main README](../README.md).
- **BigQuery.** `GENERATE_DATE_ARRAY`, `APPROX_QUANTILES`, `COUNTIF`, `QUALIFY` and
  `SAFE_DIVIDE` need swapping for other engines.
- **Materialise `core_freshdesk__ticket_lifecycle` as a table.** Three core models
  read it.
- **Not run end to end.** Reconcile a month against Freshdesk's reports first.
