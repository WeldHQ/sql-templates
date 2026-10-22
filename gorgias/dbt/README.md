# Gorgias dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Gorgias account
models/staging/stg_gorgias__*.sql                       4 thin wrappers over the raw tables
models/core/core_gorgias__ticket_lifecycle.sql          every ticket with derived response times
models/core/core_gorgias__ticket_volume_by_day.sql      created / closed / open backlog per day
models/core/core_gorgias__response_times_by_month.sql   response, resolution, one-touch, satisfaction
models/core/core_gorgias__agent_performance_by_month.sql per agent activity and satisfaction
models/core/core_gorgias__voice_calls_by_day.sql        Gorgias Voice calls
models/analytics/analytics__gorgias_*.sql               thin BI-facing contracts
tests/assert_no_duplicate_tickets.sql                   one row per ticket
tests/assert_backlog_ties_to_open.sql                   last day of backlog = open now
tests/assert_response_times_not_negative.sql            no impossible durations
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml`.

**Your time zone.** Set `reporting_timezone` in `stg_gorgias__ticket.sql` (IANA
name). It is `UTC` until you do.

No vars, no packages.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `APPROX_QUANTILES`, `JSON_VALUE`, `QUALIFY`,
  `COUNTIF` and `SAFE_DIVIDE` need swapping for other engines.
- **Materialise `core_gorgias__ticket_lifecycle` as a table.** Three core models
  read it, and it aggregates the whole message table.
- **Not run end to end.** Reconcile the open count and one month of response times
  against Gorgias' statistics first.
