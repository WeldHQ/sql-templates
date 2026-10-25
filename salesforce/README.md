# Salesforce templates

Pipeline, stage velocity, lead conversion and rep activity reporting from Weld's
Salesforce connector. BigQuery. Standard objects and fields only.

Weld connector: **Salesforce** ([docs](https://weld.app/docs/applications/salesforce)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/opportunity_pipeline.sql`](weld/core/opportunity_pipeline.sql) · [dbt](dbt/models/core/core_salesforce__opportunity_pipeline.sql) | What is open, won and lost, weighted pipeline, overdue deals, whose it is | opportunity |
| [`weld/core/pipeline_flow_daily.sql`](weld/core/pipeline_flow_daily.sql) · [dbt](dbt/models/core/core_salesforce__pipeline_flow_daily.sql) | Created, won, lost, open pipeline due, win rate and sales cycle over time | day × owner × currency |
| [`weld/core/opportunity_stage_history.sql`](weld/core/opportunity_stage_history.sql) · [dbt](dbt/models/core/core_salesforce__opportunity_stage_history.sql) | How long opportunities sit in each stage, where they stall, when they really closed | opportunity × stage entry |
| [`weld/core/lead_funnel_daily.sql`](weld/core/lead_funnel_daily.sql) · [dbt](dbt/models/core/core_salesforce__lead_funnel_daily.sql) | Leads created and converted, conversion rate, time to convert, lead to won | day × lead source |
| [`weld/core/rep_activity.sql`](weld/core/rep_activity.sql) · [dbt](dbt/models/core/core_salesforce__rep_activity.sql) | Calls, emails, completed tasks and meetings per rep | day × owner |

The two flow models are daily so the day-by-day view of leads, opportunities and
activity is there when you want it. Every ratio carries its numerator and
denominator, so a month, quarter or team is a `SUM` and one division away; both
also carry a `month` column for that.

## Read this first

**Won and lost come from Salesforce.** `is_closed` and `is_won` on the opportunity
follow each stage's settings in Setup, so custom stages are classified the way
Salesforce classifies them. There is no stage-name matching to maintain.

**Close date is not the day the deal closed.** For open opportunities it is the
expected close date. Salesforce does not change it when an opportunity is closed,
so on a closed one it is whatever the rep left in the field. `pipeline_flow_daily`
books wins and losses on it, because that is the date Salesforce's own reports use.
`opportunity_stage_history` has the timestamp the opportunity actually moved into
a closed stage (`entered_closed_at`) if you need the real day.

**Currency.** Salesforce adds `CurrencyIsoCode` to every object only when
multi-currency is enabled for the org, and the connector syncs the fields the org
has. In a single-currency org there is no currency column: `currency_code` is
`ORG_DEFAULT` and every amount is in the org currency. In a multi-currency org,
open `weld/staging/opportunity.sql` and swap the `NULL` currency line for the
commented one. Amounts stay in each opportunity's own currency; core keeps
currencies apart (`currency_code` is part of the `pipeline_flow_daily` grain) and
never adds them together. Converting to a corporate currency needs Salesforce's
`CurrencyType` or `DatedConversionRate` objects and is not done here.

**Stage history needs two extra objects.** `opportunity_stage_history` reads
`OpportunityHistory`, Salesforce's built-in log of stage, amount, probability and
close date changes, and `OpportunityStage`, the stage picklist with its sort
order. Neither needs field history tracking, but both are separate objects you
select in the sync. `opportunity_pipeline` also reads `OpportunityStage` for stage
labels and sort order.

**Days are UTC.** Salesforce stores datetimes in UTC and Weld lands them as UTC
timestamps, while reports in Salesforce use each user's time zone. Late-evening
activity can land on the next day here. Date-only fields (`CloseDate`,
`ConvertedDate`, `ActivityDate`) have no time zone and land on the right day.

## Layers

```
raw.salesforce.*          ELT output, untouched
  ↓
weld/staging/*.sql        8 thin wrappers: cast, rename, drop deleted records
  ↓
weld/core/*.sql           the reports: all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

**Staging** casts, renames and drops records in the recycle bin, and nothing else.
The connector reads with Salesforce's `queryAll`, so deleted records arrive with
`is_deleted = TRUE`; staging filters them out. `User` and `OpportunityStage` have
no such column and are not filtered.

**Core** holds the outcome split, the spines, the stage sequencing and the joins.
`opportunity_pipeline` is opportunity grain and three of the other models read it.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.salesforce.opportunity_pipeline` so core can be
renamed or re-grained without breaking them. All five are `SELECT *` on purpose.

`dbt/` holds the same models with dbt refs, generated from the Weld versions, so
the two cannot disagree about the logic. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.salesforce.opportunity}}` expects the model in a
`staging > salesforce` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| opportunity pipeline | `opportunity`, `opportunity_stage`, `account`, `user` |
| pipeline flow daily | the same |
| opportunity stage history | the same, plus `opportunity_history` |
| lead funnel daily | `lead`, plus the opportunity pipeline tables |
| rep activity | `task`, `event`, `user` |

Table names are the Salesforce object API names in snake case: `OpportunityHistory`
lands as `opportunity_history`, `OpportunityStage` as `opportunity_stage`.

**Sync `user` even if you do not report on reps.** It is the only way to turn an
owner id into a name.

## What opportunity_pipeline returns

One row per opportunity. `opportunity_status` is `Open`, `Won` or `Lost`, with
`is_open`, `is_won` and `is_lost` alongside. Money is split into `open_amount`,
`won_amount` and `lost_amount`, and `weighted_open_amount` is Salesforce's
expected revenue (amount × probability) on open opportunities.

Pipeline hygiene: `age_days` (created to close date for a closed opportunity, age
so far for an open one), `is_overdue` (open and past its expected close date) and
`days_since_last_activity` (from Salesforce's own `LastActivityDate` roll-up).
Account name, type, industry and billing country, and the owner's name, email and
active flag are joined on.

## What the other models return

- **`pipeline_flow_daily`**: per day, owner and currency: opportunities created
  (on created date), won and lost (on close date) with amounts, open opportunities
  and amount due on that day (expected close date), and the parts of win rate and
  average sales cycle. Win rate excludes open opportunities from the denominator.
  The spine runs two years ahead; open opportunities expected to close later than
  that stay in `opportunity_pipeline` but are not in `open_amount_due`.
- **`opportunity_stage_history`**: one row per stage entry, with `entered_at`,
  `exited_at`, `hours_in_stage` and `days_in_stage` (time so far for the current
  stage), the next stage, and `moved_backwards` when the next stage sits earlier in
  the Setup sort order. History rows where only the amount or close date changed are
  collapsed away. A stage visited twice gets two rows; for "time in stage" across
  opportunities, sum per opportunity and stage before averaging.
- **`lead_funnel_daily`**: per day and lead source: leads created, leads converted
  that day (whenever created), and a cohort view of the day's new leads: how many
  have converted so far, how many became an opportunity, how many became a won
  opportunity, and days to convert. Recent cohorts keep rising as leads convert.
- **`rep_activity`**: per day and owner: calls and emails logged (tasks with
  subtype `Call`, `Email` or `ListEmail`, on the task's Date), other tasks
  completed (on their Date, the due date, because no completion timestamp exists
  in every org), tasks created, and meetings held (events that have started, on
  their start day), with call and meeting minutes. Nothing after today counts.

The daily question the earlier single-query report answered (leads in and
converted, opportunities created, won and lost, tasks and events per day) is a
`SUM` over owners or sources in `lead_funnel_daily`, `pipeline_flow_daily` and
`rep_activity`.

## Schema notes

- **The public ERD for Salesforce lists only the system columns** (`id`,
  `created_date`, `last_modified_date`, `system_modstamp` and so on) for 16 objects,
  and neither `opportunity_history` nor `opportunity_stage`. The connector syncs
  every queryable object and every field the connected user can see, named as the
  API name in snake case: `StageName` lands as `stage_name`, `IsWon` as `is_won`,
  `Pricebook2Id` as `pricebook_2_id`. The columns these models read are Salesforce's
  standard fields under that rule.
- **Custom fields and record types need adding by you.** A custom field lands in
  snake case with the `__c` suffix as `_c` (`Deal_Type__c` becomes `deal_type_c`).
  Nothing here reads custom fields or `RecordTypeId`, so an org that runs several
  sales processes on record types sees them all together; add `record_type_id` in
  staging and to the grain where you need them apart.
- **Field-level security decides the columns.** A standard field hidden from the
  user Weld connects as is not synced, and a model reading it fails with an unknown
  column. Remove the line in staging or grant the field.
- **Compound address fields are skipped.** `BillingAddress` and the like are not
  synced; their parts (`billing_country`, `billing_city`, ...) are.
- **Date fields land as timestamps.** Both Salesforce `date` and `datetime` fields
  arrive as timestamps; staging takes `DATE()` of the date-only ones.
- **Deletes.** Deleted records arrive with `is_deleted = TRUE` while they are in
  the recycle bin. Records purged from it before a sync picks up the deletion stay
  in the warehouse as live rows; re-sync the table when exact parity matters.
- **Not modelled:** opportunity products (`opportunity_line_item`), contact roles,
  campaigns and cases. `OpportunityFieldHistory` is only populated for fields with
  history tracking switched on, so it is not used; `OpportunityHistory` covers the
  stage changes for every org.

## Notes

- **Roll up ratios from their parts.** Sum `opportunities_won` and
  `opportunities_lost` and divide once; averaging daily win rates weights a quiet day
  the same as a busy one. The same goes for conversion rate and average days.
- **Spines.** The flow and activity models return zeros for quiet days, so a line
  chart shows the gap instead of drawing over it.
- **Leads owned by a queue** have an owner id starting with `00G`, which is not in
  `user`.
- **Multi-org ready.** Every staging model emits a `salesforce_org` label and it is
  part of every join key and every grain in core. To add an org, `UNION ALL` a second
  block in each staging model pointing at that connector with a different label, and
  change nothing else.
- **Nothing here has been run against a warehouse.** Reconcile before relying on it:
  open pipeline by stage against an Opportunities report grouped by stage, a closed
  month of wins against the same report filtered to Closed Won, one month of
  converted leads against a Leads report filtered on Converted Date, and one rep's
  week of activity against an Activities report.

[Salesforce Object Reference: Opportunity](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunity.htm) ·
[OpportunityHistory](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunityhistory.htm) ·
[OpportunityStage](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunitystage.htm) ·
[Lead](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_lead.htm) ·
[Task](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_task.htm) ·
[Event](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_event.htm)
