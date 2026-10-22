# PagerDuty templates

Incident volume, response times and on-call load from PagerDuty: MTTA and MTTR per
service and team, who carries the incidents, and what is still open. BigQuery.

Weld connector: **PagerDuty** ([docs](https://weld.app/docs/applications/pager-duty)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/incident_response_daily.sql`](weld/core/incident_response_daily.sql) · [dbt](dbt/models/core/core_pager_duty__incident_response_daily.sql) | Service and Team Performance reports: incidents, MTTA, MTTR, escalations, interruptions | day × service × team × urgency × priority |
| [`weld/core/responder_load_daily.sql`](weld/core/responder_load_daily.sql) · [dbt](dbt/models/core/core_pager_duty__responder_load_daily.sql) | Responder report: incidents assigned, acknowledged and resolved per person | day × user |
| [`weld/core/open_incidents.sql`](weld/core/open_incidents.sql) · [dbt](dbt/models/core/core_pager_duty__open_incidents.sql) | The Incidents page filtered to open, with age | open incident (current state) |

## Layers

```
raw.pager_duty.*        ELT output, untouched
  ↓
weld/staging/*.sql      4 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.pager_duty.raw_incident}}` expects
the model in a `staging > pager_duty` folder. Mirror that structure or adjust the
refs.

## Required tables

| Model | Raw tables |
|---|---|
| incident response daily | `raw_incident` |
| responder load daily | `raw_incident`, `raw_incident_assigned_user_id`, `raw_incident_acknowledged_user_id`, `user` |
| open incidents | `raw_incident` |

## Why `raw_incident` and not `incident`

The connector syncs incidents twice. `incident` comes from the REST incidents list,
which is filtered on creation date, so the connector can only see status changes on
incidents created in the last 60 days. An incident opened three months ago and
resolved today keeps its old status in `incident`. `raw_incident` comes from
PagerDuty's Analytics API, is read by last update, and carries the timings PagerDuty
computes itself (`seconds_to_first_ack`, `seconds_to_resolve`, interruptions by time
of day). Every model here reads `raw_incident` for that reason.

The Analytics API is not included in every PagerDuty plan. If the `raw_incident`
stream fails with a permission error, your account does not have it, and these
templates will not work without rewriting them on `incident` and `log_entry`.

## Notes

- **Mean times are sums divided by counts.** `incident_response_daily` ships
  `total_seconds_to_first_ack` with `acknowledged_incidents`, and
  `total_seconds_to_resolve` with `incidents_with_resolve_time`. To get MTTA for a
  month or a team, sum both and divide. Averaging `mtta_minutes` across rows gives a
  different, wrong number.
- **Incidents are dated on creation, in UTC,** as PagerDuty's own reports are. Recent
  days still have open incidents, so their MTTR keeps moving until those resolve.
  Analytics data also arrives up to a day late; the connector re-reads two days on
  every run.
- **Interruptions belong to the incident, not the person.** PagerDuty counts how many
  notifications reached a responder during business, off and sleep hours (each
  responder's own working hours), per incident. `responder_load_daily` can say an
  incident assigned to you interrupted someone at night, not that it was you.
- **Responder load does not sum to incident totals.** An incident assigned to three
  people counts for each of them.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare a month of incident counts, MTTA and MTTR per service with
  PagerDuty's Insights or Analytics dashboard (same time zone, same filters) before
  relying on the output.

## Schema notes

There is no public ERD for this connector; tables and columns follow the connector's
own definitions.

The connector also syncs `analytics_metric_service_daily`, PagerDuty's pre-aggregated
daily metrics. That table carries no service column and is keyed on the day alone,
so it cannot be split by service. These templates aggregate `raw_incident` instead,
which gives the same metrics at any grain.

## Vendor docs

- [Analytics API: raw incident data](https://developer.pagerduty.com/api-reference/c2d493e995071-get-raw-data-multiple-incidents)
- [Analytics metric definitions](https://support.pagerduty.com/main/docs/insights)
