# Auth0 dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                          one source, one tenant
models/staging/stg_auth0__*.sql                     4 thin wrappers over the raw tables
models/core/core_auth0__tenant_activity_daily.sql   the Auth0 Dashboard by day, with failure reasons
models/core/core_auth0__logins_by_application.sql   the same per application and connection
models/core/core_auth0__monthly_active_users.sql    monthly active users, new vs. returning
models/core/core_auth0__user_signups.sql            new users by signup connection
models/analytics/analytics__auth0_*.sql             thin BI-facing contracts
tests/assert_auth0__tenant_activity_is_one_row_per_day.sql one row per day
tests/assert_auth0__application_logins_sum_to_tenant.sql   per-application logins add up to the tenant
tests/assert_auth0__active_users_split_adds_up.sql         new + returning + unmatched = active
```

These are the same models as [`../weld/`](../weld/), differing only in ref syntax.

## You supply

- **Your schema.** Change `schema:` in `sources.yml` to wherever the Auth0 tables
  land.

## Notes

- Plain SQL, no macros, no vars.
- The `logs` table is your only copy of anything older than your Auth0 plan's log
  retention. Never reset that stream.
- Not run end to end. Compare a week against the Auth0 Dashboard before relying on
  the output.
