# SevenRooms dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                       one source
models/staging/stg_seven_rooms__*.sql            3 thin wrappers over the raw tables
models/core/core_seven_rooms__*.sql              the reports
models/analytics/analytics__seven_rooms_*.sql    thin BI-facing contracts
tests/assert_lead_time_reconciles_to_covers.sql  same reservations in both models
tests/assert_outcomes_add_up.sql                 canceled + not canceled = all
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.
They are generated from the Weld versions, so the two cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
SevenRooms tables.

## Notes

- Plain SQL, no macros, no vars.
- Check the status values in your data against the outcome mapping in
  `stg_seven_rooms__reservation.sql`; see [../README.md](../README.md).
- Not run end to end. Compare a night's covers with SevenRooms first.
