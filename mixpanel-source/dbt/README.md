# Mixpanel dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                        one source, one Mixpanel project
models/staging/stg_mixpanel_source__events.sql                    one row per event: name, user, time
models/staging/stg_mixpanel_source__funnel_step.sql               saved funnels unpacked to one row per step
models/core/core_mixpanel_source__events_daily.sql                events and unique users per event per day
models/core/core_mixpanel_source__active_users_daily.sql          DAU, WAU, MAU and stickiness
models/core/core_mixpanel_source__funnel_conversion_daily.sql     saved funnels step by step per day
models/analytics/analytics__mixpanel_source_*.sql                 thin BI-facing contracts
tests/assert_one_row_per_day_and_event.sql                        stated grains hold; DAU <= WAU <= MAU
tests/assert_funnels_only_narrow.sql                              no funnel step gains users
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Mixpanel tables.

**Your properties, if you want them.** The events table has one column per event
property in your project. Staging reads only the four the connector always writes. Add
the ones you report on (plan, country, platform) in `stg_mixpanel_source__events` and
carry them into the group-bys.

## Notes

- **Materialise the events staging model as a table** on a large project. Every core
  model reads it, and `active_users_daily` reads it with a 28-day window join.
- **Not run end to end.** Nothing here has been run against a warehouse. Compare a few
  days with Mixpanel Insights before relying on the output.
