# PagerDuty dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                  one source, one account
models/staging/stg_pager_duty__*.sql                        4 thin wrappers over the raw tables
models/core/core_pager_duty__incident_response_daily.sql    incidents, MTTA, MTTR per service and team
models/core/core_pager_duty__responder_load_daily.sql       incidents per responder
models/core/core_pager_duty__open_incidents.sql             unresolved incidents with age
models/analytics/analytics__pager_duty_*.sql                thin BI-facing contracts
tests/assert_pager_duty__raw_incident_is_unique.sql                     one row per incident after de-duplication
tests/assert_pager_duty__incident_response_reconciles_to_incidents.sql  the daily report counts each incident once
tests/assert_pager_duty__no_negative_response_times.sql                 timings are never negative
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the PagerDuty
  tables land.
- **A plan with PagerDuty's Analytics API.** The `raw_incident` stream depends on it.

## Notes

- Plain SQL, no macros, no vars.
- Not run end to end. Compare a month of MTTA and MTTR per service with PagerDuty's
  analytics before relying on the output.
