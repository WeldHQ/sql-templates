# Gong dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one Gong instance
models/staging/stg_gong__*.sql                            9 thin wrappers over the raw tables
models/core/core_gong__calls.sql                          call grain, everything joined
models/core/core_gong__rep_call_activity_by_day.sql       calls and minutes per rep per day
models/core/core_gong__rep_interaction_stats_by_week.sql  talk ratio and friends per rep per week
models/core/core_gong__scorecard_scores_by_rep.sql        coaching scores per rep per month
models/analytics/analytics__gong_*.sql                    thin BI-facing contracts
tests/assert_gong__no_duplicate_calls.sql                       no fan-out at call grain
tests/assert_gong__daily_activity_ties_to_calls.sql             daily series counts every call once
tests/assert_gong__interaction_stats_are_recognised.sql         no Gong statistic silently dropped
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Gong tables.

**Your time zone**, if not UTC: the `'UTC'` literal in
`core_gong__rep_call_activity_by_day`.

## Notes

- **Plain SQL, no macros.** Multiple Gong instances work by `UNION ALL` in the
  staging models with different `gong_account` labels.
- **Check the units of the `gong_*` statistics** against one call in Gong before
  publishing them; see the main README.
- **Not run end to end.** Reconcile a week against Gong's Team Stats before relying
  on the output.
