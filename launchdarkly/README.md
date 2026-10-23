# LaunchDarkly templates

Feature flag hygiene and context activity from LaunchDarkly: which flags are live,
which are overdue for cleanup, who owns them, and how many contexts each environment
sees. BigQuery.

Weld connector: **LaunchDarkly** ([docs](https://weld.app/docs/applications/launchdarkly)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/flag_inventory.sql`](weld/core/flag_inventory.sql) · [dbt](dbt/models/core/core_launchdarkly__flag_inventory.sql) | The Flags list, with age, lifecycle state, maintainer and a cleanup flag | project × flag (current state) |
| [`weld/core/flag_health_by_project.sql`](weld/core/flag_health_by_project.sql) · [dbt](dbt/models/core/core_launchdarkly__flag_health_by_project.sql) | Flag debt per project: live, temporary, overdue, unowned | project (current state) |
| [`weld/core/context_activity.sql`](weld/core/context_activity.sql) · [dbt](dbt/models/core/core_launchdarkly__context_activity.sql) | The Contexts list, counted: total and recently active contexts | project × environment × context kind (current state) |

## Layers

```
raw.launchdarkly.*      ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, rename, convert epoch milliseconds, de-duplicate
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.launchdarkly.feature_flag}}`
expects the model in a `staging > launchdarkly` folder. Mirror that structure or
adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| flag inventory | `feature_flag`, `project` |
| flag health by project | the same, through `flag_inventory` |
| context activity | `context`, `project_environment`, `project` |

## Notes

- **Everything here is a snapshot.** Flags and contexts are synced as they are
  now. `age_days` and the context recency windows are measured from
  `CURRENT_DATE()`, so the same query gives different answers on different days. To
  chart flag debt or active contexts over time, materialise a daily copy of
  `flag_health_by_project` or `context_activity` (an incremental model keyed on the
  run date).
- **`is_cleanup_candidate` is a heuristic.** A temporary, live (not archived or
  deprecated) flag more than 90 days old. LaunchDarkly's own "ready to archive"
  status depends on flag evaluation data, which the connector does not sync. The 90
  days is one constant in `flag_inventory`; change it to your team's policy.
- **Flag keys are unique per project, not globally.** `project_id` is part of every
  key and every join here. The same goes for environment keys: `production` exists in
  every project, so `context_activity` joins environments on project and key
  together.
- **Contexts are counted per kind.** One person evaluated as a `user` and as a
  `device` context is two contexts, as in LaunchDarkly. `contexts_seen_this_month` is
  the closest column to LaunchDarkly's monthly active contexts, but LaunchDarkly
  computes billable usage on its side; check it against the Usage page before using
  it for plan decisions.
- **Deleted flags stay.** A flag deleted (rather than archived) in LaunchDarkly keeps
  its last synced row. Archive instead of deleting if you want the inventory to
  reflect it.
- **Per-environment flag state is not used.** Whether a flag is on in production
  lives in `feature_flag_environment`, whose columns are generated from the API
  response and are not listed in the public schema. Add it to `flag_inventory` if you
  need it once you have confirmed the column names in your warehouse.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare the live and archived flag counts per project with the
  LaunchDarkly Flags list (filter by project, archived on and off) before relying on
  the output.

## Schema notes

- `project_environment.project_id` is synced (it links each environment to its
  project), but the public ERD does not list it.
- `feature_flag_variations`, `feature_flag_environment` and the rule tables are
  shown in the ERD with their key columns only; their other columns depend on what
  the LaunchDarkly API returns for your flags. None of the models here read them.

## Vendor docs

- [Archiving flags](https://launchdarkly.com/docs/home/flags/archive)
- [Contexts](https://launchdarkly.com/docs/home/observability/contexts)
- [REST API reference: feature flags](https://launchdarkly.com/docs/api/feature-flags)
