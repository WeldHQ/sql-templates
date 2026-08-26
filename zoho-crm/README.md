# Zoho CRM templates

Pipeline, activity and account reporting from Weld's Zoho CRM connector. BigQuery,
org reporting currency.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/deal_pipeline.sql`](weld/core/deal_pipeline.sql) · [dbt](dbt/models/core/core_zoho_crm__deal_pipeline.sql) | What is open, won and lost, and whose it is | deal |
| [`weld/core/deal_flow_by_month.sql`](weld/core/deal_flow_by_month.sql) · [dbt](dbt/models/core/core_zoho_crm__deal_flow_by_month.sql) | Created / won / lost and win rate over time | month × owner |
| [`weld/core/rep_activity.sql`](weld/core/rep_activity.sql) · [dbt](dbt/models/core/core_zoho_crm__rep_activity.sql) | How much each rep is doing | day × owner |
| [`weld/core/account_360.sql`](weld/core/account_360.sql) · [dbt](dbt/models/core/core_zoho_crm__account_360.sql) | People, pipeline and last touch per account | account |

## Read this first — what this connector cannot do

The Zoho CRM connector syncs 12 modules as flat tables. Three limits change what is
worth building, and all three are properties of the connector, not of these models:

**1. Activities have no parent record.** Zoho's Calls, Events and Tasks modules each
carry `What_Id` / `Who_Id` — the deal, account, contact or lead the activity belongs
to. Neither field is synced. `owner_id` is the only foreign key on all three
streams, so activity can be counted **per rep and never per deal**. There is no
honest "activities per won deal" from this connector alone.

The exception is **Notes**, whose `Parent_Id` *is* synced. That single column is why
`account_360` can report a last-touch date at all.

**2. There is no won/lost flag.** Zoho ships no `is_won` or `is_closed` boolean, no
probability and no forecast category. `deal_pipeline` derives the outcome from the
stage *string*. Zoho's own defaults are covered — including `Closed-Lost to
Competition`, which is why the match is `LIKE '%lost%'` and not an equality list —
but a custom stage called `Contract Signed` or `Churned` will read as open pipeline
until you add it. Run
[`assert_deal_stages_are_classified`](dbt/tests/assert_deal_stages_are_classified.sql);
this is the one edit almost every org has to make.

**3. There is no history.** Weld's Zoho CRM connector does not support history
tables, and the deal stream carries no stage-change audit. Nothing here can tell
you what the pipeline looked like last month, how long a deal sat in Negotiation,
or when a deal actually closed — `closing_date` is the *expected* close date and
Zoho does not clear it on close. **If stage velocity or a pipeline trend matters,
materialise `deal_pipeline` on a daily schedule and keep the runs.** That is the
only route to history, and it only starts working from the day you set it up.

Two smaller ones worth knowing:

- **`call_duration` is a string.** Zoho's API reference documents it as `hh:mm`; the
  CRM UI shows `mm:ss` for short calls, and the stream carries no
  `Call_Duration_in_seconds` column to settle it. `staging/call.sql` parses the
  documented `hh:mm`. Reconcile against one call of known length before reporting on
  call time.
- **Deletes are not captured.** Zoho's records API does not report deletions, so a
  deleted record stops receiving updates and stays in your warehouse. Run a ReSync
  on the affected table when the destination has to match Zoho exactly.

## Layers

```
raw.zoho_crm.*          ELT output, untouched
  ↓
weld/staging/*.sql      9 thin wrappers: cast, rename, blanks to NULL
  ↓
weld/core/*.sql         the reports - all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and normalises, and nothing else. It also unpicks Zoho's
lookup flattening: a lookup field arrives as an `_id` / `_name` / `_email` triple,
so `Account_Name` on a deal becomes `account_name_id` — which is the account's id,
despite the name. Staging renames it to `account_id` and drops the denormalised
label, so a renamed rep or account does not leave stale copies of its old name
scattered across every module.

**Core** holds the stage classification, the date spines and the joins. This is the
layer worth reviewing. `deal_pipeline` is deal-grain and the other three read it.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.zoho_crm.deal_pipeline` so core stays free to be
renamed or re-grained. All four are `SELECT *` — that is the point, not an oversight.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.zoho_crm.deal}}` expects the model in a `staging > zoho_crm`
folder — mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| deal pipeline | `deal`, `account`, `user` |
| deal flow by month | the same |
| rep activity | `call`, `event`, `task`, `user` |
| account 360 | `account`, `contact`, `deal`, `user`, `note` |

**Sync the `user` stream even if you do not think you need it.** It is the only
dimension the other modules can join to, and without it every report groups by a
NULL rep name. [`assert_owner_ids_resolve`](dbt/tests/assert_owner_ids_resolve.sql)
is there to catch exactly that.

Three synced modules are deliberately not modelled, because nothing in the schema
joins to them: **campaign** (no deal or lead key, and no budget or response
metrics), and **product** and **price_book** (no line items on deals, and no key
between the two).

## What deal_pipeline returns

Grain is one row per deal. `stage_status` is `Open`, `Won` or `Lost`, with
`is_open` / `is_won` / `is_lost` alongside it, and `amount` split into
`pipeline_amount`, `won_amount` and `lost_amount` so BI can sum a column instead of
repeating the CASE.

`age_days` is time-to-close for a decided deal and time-in-pipeline for an open
one. `is_overdue` flags open deals whose expected close date has already passed —
the cheapest pipeline-hygiene number available, and usually the first thing a sales
lead asks for. Account (`account_name`, `industry`) and owner (`owner_name`,
`owner_email`, `owner_role`, `owner_is_active`) are joined on. A deal owned by a
deactivated rep is unmanaged pipeline; `owner_is_active` is how you find it.

## Notes

- **`win_rate` excludes open deals from the denominator.** Counting them as
  not-yet-won drags every current month down and makes the trend look like a
  collapse. Both a count-based and a value-based rate are returned.
- **`deal_flow_by_month` books wins on `closing_date`**, because no real close
  timestamp is synced. `modified_time` would be worse: it moves every time anyone
  edits the record, so a note added in August would move a June win.
- **Both time-series models are built on a spine**, so a rep with a quiet month
  still returns a row of zeros instead of vanishing from the series and letting a
  BI line chart interpolate straight over the gap.
- **Multi-org ready.** Every staging model emits a `zoho_org` label and it is part
  of every join key. To add an org, `UNION ALL` a second block in each staging model
  with a different label — and change nothing else.
- **Treat every model as unverified until you have reconciled it.** Open pipeline
  against Zoho's own Deals view is the check that matters; if it disagrees, the
  stage classification is where to look first.

[Zoho CRM connector docs](https://weld.app/docs/applications/zoho-crm) ·
[Full walkthrough](https://weld.app/blog/zoho-crm-connector-sql-reports)
