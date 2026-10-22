# Auth0 templates

Logins, signups, failures and active users from your Auth0 tenant, rebuilt from the
tenant log and Auth0's own daily counters. BigQuery.

Weld connector: **Auth0** ([docs](https://weld.app/docs/applications/auth0)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/tenant_activity_daily.sql`](weld/core/tenant_activity_daily.sql) · [dbt](dbt/models/core/core_auth0__tenant_activity_daily.sql) | The Auth0 Dashboard: logins, signups, leaked passwords, plus failures by reason and daily active users | day |
| [`weld/core/logins_by_application.sql`](weld/core/logins_by_application.sql) · [dbt](dbt/models/core/core_auth0__logins_by_application.sql) | The same activity split by application and connection | day × client × connection |
| [`weld/core/monthly_active_users.sql`](weld/core/monthly_active_users.sql) · [dbt](dbt/models/core/core_auth0__monthly_active_users.sql) | Monthly active users, new vs. returning | month |
| [`weld/core/user_signups.sql`](weld/core/user_signups.sql) · [dbt](dbt/models/core/core_auth0__user_signups.sql) | New users by signup connection, with email verification and return rates | signup day × connection × provider |

## Layers

```
raw.auth0.*             ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, rename, de-duplicate, label log event codes
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.auth0.logs}}` expects the model in
a `staging > auth0` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| tenant activity daily | `stats_daily`, `logs` |
| logins by application | `logs` |
| monthly active users | `logs`, `users` |
| user signups | `users`, `user_identities` |

## How the log is read

Auth0 writes one log event per login, signup, token exchange and so on, each with a
short type code (`s` for a successful login, `fp` for a wrong password, `ss` for a
signup). `staging.auth0.logs` maps those codes to a handful of categories in one
`CASE`, following Auth0's
[log event type codes](https://auth0.com/docs/deploy-monitor/logs/log-event-type-codes).
Every core model counts categories, never raw codes, so if you disagree with a
mapping there is one place to change it. Codes outside the mapping land in `other`
with the raw code kept in `event_type`.

**Active** means authenticated in any way: an interactive login, a silent
re-authentication, or a token exchange made for a user (refresh token, authorization
code and so on). Machine-to-machine client credentials have no user and are not
counted.

## Notes

- **The log only goes back as far as your plan keeps it.** Auth0 retains tenant logs
  for 1 to 30 days, and the connector's first run starts at the oldest event the
  tenant still has. From then on the warehouse keeps everything, so your history
  grows with every sync, but nothing before the first sync can be recovered. Do not
  reset the `logs` stream once you rely on it.
- **Two sources for logins and signups.** `auth0_logins` and `auth0_signups` in
  `tenant_activity_daily` are Auth0's own counters and reach further back.
  `log_logins` and `log_signups` are counted from the log and come with the
  breakdowns. On days with both they should be close; `has_log_coverage` tells you
  which days have log data at all.
- **Monthly active users is a reporting number, not your invoice.** Auth0 computes
  billable active users on its side. Reconcile a closed month against Tenant
  Settings, Usage, before using it for anything contractual.
  `is_complete_month` is FALSE for the first month the log does not fully cover and
  for the current month.
- **Distinct user counts are not additive.** `users_logging_in` in
  `logins_by_application` is distinct per application and connection; a user on two
  apps counts in both. Use `tenant_activity_daily` for tenant-wide totals.
- **Deleted users stay.** Auth0 never returns a deleted user, so `users` keeps the
  last state it saw. `monthly_active_users.active_users_not_in_users_table` surfaces
  activity from users the users table does not have.
- **Personal data is left out of staging.** Email, names and IP addresses are in the
  raw tables but not selected, since none of the reports need them.
- **Times are UTC.** Auth0 reports in UTC, and so do these models.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare a week of `auth0_logins` and `log_logins` against the
  Auth0 Dashboard before relying on the output.

## Schema notes

The public ERD and the connector definition agree on every table and column used
here.

## Vendor docs

- [Log event type codes](https://auth0.com/docs/deploy-monitor/logs/log-event-type-codes)
- [Log stream event filters](https://auth0.com/docs/customize/log-streams/event-filters), the same codes grouped by category
- [Management API reference](https://auth0.com/docs/api/management/v2)
