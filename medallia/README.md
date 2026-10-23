# Medallia templates

Feedback volume and response rate, answers with scores, NPS by unit and text
analytics topics from Weld's Medallia connector. BigQuery, UTC.

Weld connector: **Medallia** ([docs](https://weld.app/docs/applications/medallia)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/feedback_volume.sql`](weld/core/feedback_volume.sql) · [dbt](dbt/models/core/core_medallia__feedback_volume.sql) | Invitations, responses and response rate per unit | day × account × unit |
| [`weld/core/answer_detail.sql`](weld/core/answer_detail.sql) · [dbt](dbt/models/core/core_medallia__answer_detail.sql) | Every answer with its label and score | account × feedback record × question × position |
| [`weld/core/nps_by_unit_month.sql`](weld/core/nps_by_unit_month.sql) · [dbt](dbt/models/core/core_medallia__nps_by_unit_month.sql) | Net Promoter Score per unit | month × account × unit × question |
| [`weld/core/topic_volume.sql`](weld/core/topic_volume.sql) · [dbt](dbt/models/core/core_medallia__topic_volume.sql) | Which topics customers comment on, and how often | month × account × unit × topic |

## Read this first: Medallia is configured per company

**1. The feedback table's columns are your instance's fields.** Every single-valued
record field (`e_*`, `a_*`, `k_*`, ...) becomes a column of `feedback`, so the table
differs per company. `staging/feedback.sql` reads only the columns the connector
always writes: `id`, `timezone`, `a_unit_identifier`, `e_status`, `e_survey_method`,
`e_survey_source`, `e_creationdate`, `e_responsedate`, `e_accepteddate`,
`e_expirationdate` and `e_lastupdated`. Add the fields you segment on (region,
touchpoint, product line) to that model and they flow through to core.

**2. Which question is NPS is your configuration.** There is no fixed field id for
likelihood to recommend. `nps_by_unit_month` picks questions whose name contains
"recommend", which is a guess.
[`assert_medallia__nps_questions_are_0_to_10`](dbt/tests/assert_medallia__nps_questions_are_0_to_10.sql)
shows what it picked; replace the rule with your question ids (often `q_ltr` or
similar) in the `nps_questions` CTE. This is the one edit most instances need.

**3. Answers are rows, not columns.** Every question (`q_*`) and every multi-valued
field lands in `feedback_answer`, one row per value. For a question with fixed
options, the value is the option id, and `field_option` gives its label and numeric
value. `answer_detail` does that lookup once.

**4. Units are only those seen on feedback.** The connector reaches units through
each record's primary unit, so `unit` holds the units of synced records, not the full
unit hierarchy. Records join to a unit on `a_unit_identifier`. Unit groups are synced
(`unit_group`, `group`) but not modelled; join them on `unit_id` to roll up to a
region or brand.

## Layers

```
raw.medallia.*          ELT output, untouched
  ↓
weld/staging/*.sql      6 thin wrappers: cast, rename, dedupe
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps the latest copy of each row.

**Core** holds the option lookup, the NPS question rule, the response rate cohort and
the day spine. `nps_by_unit_month` reads `answer_detail`, so the two agree on what a
score is. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.medallia.nps_by_unit_month` so core stays free to be
renamed or re-grained. All four are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.medallia.feedback}}` expects the model in a `staging > medallia`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| feedback volume | `feedback`, `unit` |
| answer detail | `feedback`, `feedback_answer`, `field_meta_data`, `field_option`, `unit` |
| NPS by unit month | the same as answer detail |
| topic volume | `feedback`, `feedback_topic`, `unit` |

`feedback_answer`, `feedback_topic` and `unit` are tables of the `feedback` stream;
`field_option` is a table of the `field_meta_data` stream. Topics need the text
analytics permissions on the Medallia API account.

## What feedback_volume returns

A feedback record is created when an invitation goes out and answered later, so the
model counts each event on its own date: `records_created` on `e_creationdate`,
`responses` on `e_responsedate`. `response_rate` is a cohort rate: of the records
created that day, the share answered by now. It keeps rising for recent days as late
answers arrive. Dividing `responses` by `records_created` mixes two different sets of
records and is not a response rate.

Records with no creation date (web intercepts and other unsolicited feedback, on most
instances) count as responses but never in the cohort columns.

## Notes

- **NPS is computed from counts.** Promoters score 9 or 10, passives 7 or 8,
  detractors 0 to 6; `nps` is the share of promoters minus the share of detractors,
  times 100. Answers that are not a whole number from 0 to 10, such as an "N/A"
  option, are counted in `excluded_answers` and left out. Roll up from the summed
  counts, never by averaging monthly or per-unit NPS.
- **The score is the option's numeric value.** For a fixed-option question the score
  is `field_option.numeric_value`, the number Medallia itself aggregates, not the
  label text.
- **Topic counts are distinct records.** A record mentioning a topic in two comments
  counts once. Neither `feedback_records` nor `commenting_records` can be summed
  across months or units.
- **Updates can leave stale rows.** When a record is updated and a multi-valued answer
  shrinks, or a comment is re-tagged, the rows that were removed stay in
  `feedback_answer` and `feedback_topic` until a full re-sync. Deletes are not captured
  either.
- **Dates are UTC.** The connector converts Medallia's wall-clock datetimes to UTC
  using each record's time zone. Medallia's reports use the unit's local time, so a
  day's count can differ near midnight. `feedback.timezone` is kept if you want to
  report in local time.
- **History is limited to the sync start.** The first sync reads two years of feedback
  by default.
- **Multi-account ready.** Every staging model emits a `medallia_account` label and it
  is part of every join key. To add an instance, `UNION ALL` a second block in each
  staging model with a different label, and change nothing else.
- **Not run against a warehouse.** These models were checked for syntax and against the
  connector's schema, not executed on real data. Reconcile one unit's monthly NPS and
  response count against Medallia's own reports before relying on the output.

[Medallia Query API](https://docs.medallia.com/en/medallia-experience-cloud/integration/apis/query-api) ·
[Weld Medallia connector docs](https://weld.app/docs/applications/medallia)
