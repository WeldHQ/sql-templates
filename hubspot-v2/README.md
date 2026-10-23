# HubSpot templates

Deal pipeline, stage velocity, rep activity and account reporting from Weld's
HubSpot connector. BigQuery, in the portal's home currency and time zone.

Weld connector: **HubSpot** ([docs](https://weld.app/docs/applications/hubspot)).
These models target the current HubSpot connector (integration id `hubspot-v2`).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/deal_pipeline.sql`](weld/core/deal_pipeline.sql) · [dbt](dbt/models/core/core_hubspot_v2__deal_pipeline.sql) | What is open, won and lost, weighted pipeline, whose it is | deal |
| [`weld/core/deal_flow_by_month.sql`](weld/core/deal_flow_by_month.sql) · [dbt](dbt/models/core/core_hubspot_v2__deal_flow_by_month.sql) | Created, won, lost, forecast and win rate over time | month × pipeline × owner |
| [`weld/core/deal_stage_history.sql`](weld/core/deal_stage_history.sql) · [dbt](dbt/models/core/core_hubspot_v2__deal_stage_history.sql) | How long deals sit in each stage, and where they stall | deal × stage entry |
| [`weld/core/deal_activity.sql`](weld/core/deal_activity.sql) · [dbt](dbt/models/core/core_hubspot_v2__deal_activity.sql) | Calls, emails, meetings, notes and tasks logged against each deal, first and latest | deal |
| [`weld/core/rep_activity.sql`](weld/core/rep_activity.sql) · [dbt](dbt/models/core/core_hubspot_v2__rep_activity.sql) | Calls, emails, meetings, notes and tasks per rep | day × owner |
| [`weld/core/company_360.sql`](weld/core/company_360.sql) · [dbt](dbt/models/core/core_hubspot_v2__company_360.sql) | Contacts, pipeline, revenue and last touch per company | company |

## Read this first

**Won and lost come from HubSpot, not from stage names.** The deal stream carries
`hs_is_closed` and `hs_is_closed_won`, which follow each stage's closed-won or
closed-lost setting in your pipeline settings. Custom stages are classified the way
HubSpot classifies them, with no pattern matching to maintain.

**Sum `amount_home_currency`, never `amount`.** `amount` is in each deal's own
currency. HubSpot converts every deal into the portal's company currency using the
exchange rates set in the portal, and that converted figure is the only one that
can be added up. All money columns in core are in home currency.

**Close date is the real close date for closed deals, by default.** HubSpot sets
`closedate` to the day a deal moves into a closed-won or closed-lost stage. A portal
can switch that automation off in its pipeline settings; if yours has, wins are
booked on whatever close date the rep entered. For open deals it is always the
expected close date.

**Stage history needs the `deal_property_history` stream.** HubSpot records every
change to every deal property; the connector syncs that as `deal_property_history`.
`deal_stage_history` reads the `dealstage` changes from it. Without the stream the
model is empty and nothing else is affected.

**Days are in the portal's time zone.** HubSpot stores timestamps in UTC and draws
its reports in the portal's time zone. Core reads the zone from `account_details`,
so nothing is hardcoded. If that stream is not synced, dates fall back to UTC and
late-evening activity can land on the next day.

## Layers

```
raw.hubspot_v2.*          ELT output, untouched
  ↓
weld/staging/*.sql        11 thin wrappers: cast, rename, drop archived records
  ↓
weld/core/*.sql           the reports: all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

**Staging** casts, renames and drops archived (deleted) records, and nothing else.
HubSpot properties arrive as `properties_<name>` columns; staging gives them plain
names. Every cast is written to work whether the raw column holds the typed value or
its string form, because a portal admin can change a property's type.

**Core** holds the outcome split, the primary-company pick, the stage sequencing and
the spines. `deal_pipeline` is deal-grain and three of the other models read it.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.hubspot_v2.deal_pipeline` so core can be renamed or
re-grained without breaking them. All six are `SELECT *` on purpose.

`dbt/` holds the same models with dbt refs, generated from the Weld versions, so the
two cannot disagree about the logic. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.hubspot_v2.deal}}` expects the model in a `staging > hubspot_v2`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| deal pipeline | `deal`, `deal_association`, `pipeline`, `pipeline_stage`, `owner`, `company`, `account_details` |
| deal flow by month | the same |
| deal stage history | the same, plus `deal_property_history` |
| deal activity | `engagement`, `deal` |
| rep activity | `engagement`, `owner`, `account_details` |
| company 360 | the deal pipeline tables, plus `contact` |

`account_details` is optional (dates fall back to UTC without it). Everything else in
a row is needed for that model to build.

**Sync `owner` even if you do not report on reps.** It is the only way to turn an
owner id into a name, and deals, companies and activities all carry owner ids.

## What deal_pipeline returns

One row per deal. `deal_status` is `Open`, `Won` or `Lost`, with `is_open`,
`is_won` and `is_lost` alongside. Money is split into `open_amount`, `won_amount` and
`lost_amount`, and `weighted_open_amount` multiplies open amount by the deal's stage
probability: the deal's own `hs_deal_stage_probability` where set, otherwise the
stage default from the pipeline.

Pipeline hygiene: `age_days` (time to close for a closed deal, time open for an open
one), `is_overdue` (open and past its expected close date) and
`has_no_next_activity` (open with nothing scheduled). HubSpot's own activity
roll-ups on the deal (`num_activities`, `num_times_contacted`, `last_activity_at`,
`next_activity_at`) come along.

Counts of the activities logged against each deal are in a separate model,
`deal_activity`, so `deal_pipeline` and everything built on it run without the
`engagement` stream. See below.

Each deal gets **one** company: the primary association if there is one, otherwise
the lowest associated company id. That keeps the model at deal grain and makes
`company_360` add up to the same totals.

## What deal_activity returns

One row per deal that has at least one activity logged against it; join it to
`deal_pipeline` on `hubspot_portal` and `deal_id`. `logged_activities` and
`logged_emails`, `logged_calls`, `logged_connected_calls`, `logged_meetings`,
`logged_meetings_completed`, `logged_notes`, `logged_tasks` count the activities
associated with the deal, with `first_logged_activity_at` and
`last_logged_activity_at` (activities in the past only).

**An activity associated with two deals counts on both**, so these columns are
right per deal and too high when summed over deals. For totals, use
`rep_activity`, which counts each activity once.

## Schema notes

- **Custom properties are not modelled.** The connector syncs every property in your
  portal, custom ones included, as `properties_<name>` columns. The templates only
  read HubSpot's standard properties, which every portal has. Add your own fields in
  staging.
- **Activities use the `engagement` stream.** It is HubSpot's combined activity feed
  (calls, emails, meetings, notes, tasks) and carries the owner and a typed
  `metadata` JSON. Call duration and status, task status and meeting outcome are
  parsed from that JSON. The separate `call` object stream holds the same calls with
  more detail and is not needed here.
- **Only active pipelines are synced.** A deal still in a pipeline that has been
  archived keeps its stage id but gets no pipeline or stage label. In
  `deal_stage_history` labels are looked up by stage id across every synced deal
  pipeline, so a deal moved between two active pipelines keeps labels for both.
- **Activity associations come from the engagement's `deal_ids` array**, read as
  a native array column. The connector also syncs separate association tables for
  some activity objects; they are not needed here.
- **The public ERD shows the top-level `created_at` and `updated_at` columns on
  `deal`, `company` and `contact` as integers.** The connector declares them as
  timestamps. These models use HubSpot's `createdate` properties instead, which are
  timestamps in both, so the difference does not matter here.
- **Deletes.** The connector syncs archived (deleted) deals, companies and contacts
  with `archived = true`; staging drops them. Owners who were deactivated are kept
  and flagged with `owner_is_active = FALSE`, because their history still exists.

## Notes

- **`win_rate` excludes open deals from the denominator.** To roll it up over
  months or owners, sum `deals_won` and `deals_lost` and divide once; averaging the
  monthly rates weights a quiet month the same as a busy one.
- **Time series are built on spines**, so an owner with a quiet month or day still
  gets a row of zeros instead of disappearing from a line chart.
- **Stage history counts re-visits.** A deal that goes Proposal → Negotiation →
  Proposal has two Proposal rows. `moved_backwards` flags the step back. For "time
  in stage" across deals, sum `days_in_stage` per deal and stage before averaging.
- **Multi-portal ready.** Every staging model emits a `hubspot_portal` label and it
  is part of every join key and of the grain in core. To add a portal, `UNION ALL` a
  second block in each staging model pointing at that connector with a different
  label, and change nothing else.
- Metric definitions were cross-checked against Fivetran's open-source
  `dbt_hubspot` package; the SQL here is written independently for Weld's schema.
  Weld's HubSpot schema differs from the one that package targets, so the
  comparison was of definitions, not table shapes.
- **Nothing here has been run against a warehouse.** Reconcile before relying on it:
  open pipeline and weighted amount against HubSpot's deal board for one pipeline,
  a closed month of wins against the "Deals won" report, and one rep's week of
  activities against the Activities report.

[HubSpot default deal properties](https://knowledge.hubspot.com/properties/hubspots-default-deal-properties) ·
[HubSpot CRM API: deals](https://developers.hubspot.com/docs/api/crm/deals) ·
[Property history](https://developers.hubspot.com/docs/api/crm/properties)
