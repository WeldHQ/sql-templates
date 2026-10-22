# Calendly dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                          one source, one organisation
models/staging/stg_calendly__*.sql                  4 thin wrappers over the raw tables
models/core/core_calendly__scheduled_events.sql     meeting grain, outcome classified
models/core/core_calendly__meetings_by_day.sql      daily series per host and event type
models/core/core_calendly__bookings_by_source.sql   UTM funnel, reschedules followed
models/analytics/analytics__calendly_*.sql          thin BI-facing contracts
tests/assert_no_duplicate_scheduled_events.sql      multi-host dedupe holds
tests/assert_daily_meetings_tie_to_events.sql       daily series counts each meeting once
tests/assert_bookings_reconcile_to_events.sql       funnel bookings = new bookings on events
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Calendly tables.

**Your time zone**, if not UTC: the `'UTC'` literal in `meetings_by_day` and
`bookings_by_source`.

## Notes

- **Plain SQL, no macros.** Multiple Calendly organisations work by `UNION ALL` in
  the staging models with different `calendly_account` labels.
- **`bookings_by_source` uses a recursive CTE** to walk reschedule chains. BigQuery
  supports `WITH RECURSIVE`; on other warehouses check the syntax.
- **Not run end to end.** Reconcile a month against Calendly's Analytics page before
  relying on the output.
