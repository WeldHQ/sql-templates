# Gong templates

Call activity, conversation statistics and coaching scorecards per rep from Weld's
Gong connector. BigQuery.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/calls.sql`](weld/core/calls.sql) · [dbt](dbt/models/core/core_gong__calls.sql) | Every call with rep, participants, talk time, Gong's stats and CRM links | call |
| [`weld/core/rep_call_activity_by_day.sql`](weld/core/rep_call_activity_by_day.sql) · [dbt](dbt/models/core/core_gong__rep_call_activity_by_day.sql) | Gong Team Stats, activity: calls and minutes per rep | day × rep |
| [`weld/core/rep_interaction_stats_by_week.sql`](weld/core/rep_interaction_stats_by_week.sql) · [dbt](dbt/models/core/core_gong__rep_interaction_stats_by_week.sql) | Gong Team Stats, interaction: talk ratio, monologue, patience, interactivity | ISO week × rep |
| [`weld/core/scorecard_scores_by_rep.sql`](weld/core/scorecard_scores_by_rep.sql) · [dbt](dbt/models/core/core_gong__scorecard_scores_by_rep.sql) | Coaching: calls reviewed and average scores received | review month × rep × scorecard |

## Read this first: what this connector cannot do

**1. Interaction statistics arrive with no stated unit.** The connector syncs
Gong's per-call interaction statistics as name and value pairs (`Talk Ratio`,
`Longest Monologue`, `Longest Customer Story`, `Interactivity`, `Patience`,
`Question Rate`). Gong's API reference sits behind a Gong login and does not spell
out whether talk ratio is a fraction or a percentage, or whether monologue and
patience are in seconds. These models pass the values through unconverted as
`gong_*` columns. Open one call in Gong, compare, and label your dashboard
accordingly before anyone reads them.

Because of that, `calls` also computes its own talk ratio from per-speaker talk
seconds: `rep_talk_ratio` (the call owner's share of all talk time) and
`company_talk_ratio` (everyone internal). Those are always 0 to 1 and can be
audited row by row.

**2. Per-person interaction statistics are not synced.** The connector syncs the
call's interaction statistics, not the per-participant breakdown. Stats are
attributed to the call's primary user (its owner, usually the host). A call where a
manager joined a rep is that rep's call.

**3. CRM links are ids, not deals.** `call_context_integration` carries the CRM
objects a call is attached to (account, opportunity, contact, lead) with their id
and type. Deal amount, stage or close date are not on it in a usable shape, so
joining a call to its deal's outcome needs your CRM connector, keyed on
`crm_deal_ids` / `crm_account_ids`. The type labels are the CRM's own
(`Opportunity` in Salesforce, `Deal` in HubSpot); `calls` matches both.

**4. Emails, Engage tasks and per-user aggregate activity stats are not synced.**
Gong's own "Activity" numbers include emails and Engage steps; these models cover
recorded and imported calls only.

## Layers

```
raw.gong.*              ELT output, untouched
  ↓
weld/staging/*.sql      9 thin wrappers: cast, rename, dedupe
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, normalises Gong's enums, dedupes on each table's key and turns
the statistic names into stable snake_case keys. The call stream is re-read weekly
to pick up edits to older calls, so the dedupe is there to keep a re-read from ever
double counting.

**Core** holds the call-grain join and the rollups. `calls` aggregates every child
table to call grain before joining, so talk time is never multiplied by the number
of participants. The other three read it or the scorecard tables.

**Analytics** exists for indirection, not transformation. All four are `SELECT *` on
purpose.

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.gong.call}}` expects the model in a `staging > gong` folder.
Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| calls | `call`, `call_participant`, `call_speaker`, `call_interaction`, `call_context_integration`, `user` |
| rep call activity by day | the same |
| rep interaction stats by week | the same |
| scorecard scores by rep | `answered_scorecard`, `answered_scorecard_answer`, `scorecard_question`, `user` |

**Sync the `user` stream.** It is the only place rep names and managers come from.

Synced but not modelled: transcripts, trackers, topics, highlights and outlines
(text and keyword detail, better queried ad hoc than pre-aggregated), library
folders, permission profiles, Engage flows and the CRM entity schemas.

## What calls returns

One row per call. Call facts (`started_at`, `duration_minutes`, `scope`,
`direction`, `system`, `call_outcome_name`), the rep and their manager,
participant counts split internal and external, talk seconds (total, company, rep)
with the two computed talk ratios, Gong's six interaction statistics as
`gong_*` columns, question counts, and the linked CRM account and deal ids.

`scope` is Gong's classification: `External` when at least one participant is
outside your company domains, otherwise `Internal` or `Unknown`. Interaction stats
by week use external calls only.

## Notes

- **Rep averages are averages of per-call values,** which is how Gong's help centre
  defines a rep's average talk ratio: every call weighs the same.
  `talk_time_weighted_rep_talk_ratio` is the alternative where long calls dominate.
  To roll up to month or team, sum the `*_sum` and `*_calls` columns and divide;
  averaging the weekly averages gives a mean of means.
- **Scorecard scores are normalised to 0 to 1** using each question's range, because
  scale questions can use different ranges. Raw averages are kept for matching the
  Gong UI on a single scorecard. Months are by review date, not call date.
- **Days are cut in UTC.** Change the `'UTC'` literal in `rep_call_activity_by_day`
  to your reporting zone. `calls.call_date` and the weekly model use UTC dates.
- **Multi-account ready.** Every staging model emits a `gong_account` label and it is
  part of every join key. To add a Gong instance, `UNION ALL` a second block in each
  staging model with a different label, and change nothing else.
- **Not run against a warehouse.** These models were checked for syntax and schema,
  not executed. Reconcile a week of `rep_call_activity_by_day` and
  `rep_interaction_stats_by_week` against Gong's Team Stats page (same reps, same
  date range, external calls) before relying on the output.

[Gong API reference](https://gong.app.gong.io/settings/api/documentation) (requires a Gong login) ·
[Gong help: analyze team performance](https://help.gong.io/docs/analyze-team-performance)
