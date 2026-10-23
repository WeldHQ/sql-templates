# Typeform templates

Response volume, answer distributions and NPS from Weld's Typeform connector.
BigQuery, UTC.

Weld connector: **Typeform** ([docs](https://weld.app/docs/applications/typeform)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/response_volume.sql`](weld/core/response_volume.sql) · [dbt](dbt/models/core/core_typeform__response_volume.sql) | How many responses each form gets, and how long they take | day × account × form |
| [`weld/core/answer_detail.sql`](weld/core/answer_detail.sql) · [dbt](dbt/models/core/core_typeform__answer_detail.sql) | What people answered, question by question | account × response × question × selected choice |
| [`weld/core/score_summary.sql`](weld/core/score_summary.sql) · [dbt](dbt/models/core/core_typeform__score_summary.sql) | NPS, average score and top-two-box per scale question | month × account × form × question |

## Read this first: what this connector cannot do

**1. Only submitted responses are synced.** Views, starts and partial responses
are not. That rules out completion rate, drop-off per
question and the "views → starts → submissions" funnel on Typeform's Results page.
`response_volume` reconciles to the Results page's response count, nothing more.

**2. Forms are their current definition.** `form_field` holds each form's questions
as they are now. When a question is deleted, its old answers keep the field id but
lose their question title; `answer_detail` falls back to the answer's own `field_ref`
so those rows still group, but the human-readable title is gone. When a question is
reworded, every past answer shows the new wording.

**3. Two answer types arrive empty.** Answers to Website (`url`) and Payment
questions have no value column, so they appear in `answer_detail` with
`answer_value` NULL.

## Layers

```
raw.typeform.*          ELT output, untouched
  ↓
weld/staging/*.sql      6 thin wrappers: cast, rename, dedupe
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps the latest copy of each row. Typeform returns one
value column per answer type (`text`, `number`, `boolean`, `email`, `date`, ...);
staging prefixes them with `answer_` and leaves them separate.

**Core** holds the joins, the NPS and top-two-box logic and the day spine. This is
the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.typeform.score_summary` so core stays free to be
renamed or re-grained. All three are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.typeform.response}}` expects the model in a `staging > typeform`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| response volume | `response`, `form` |
| answer detail | `response`, `response_answer`, `response_answer_choice`, `form_field`, `form` |
| score summary | `response`, `response_answer`, `form_field`, `form_field_property`, `form` |

`response_answer` and `response_answer_choice` are tables of the `response` stream,
and `form_field` and `form_field_property` are tables of the `form` stream, so
syncing the two streams gives you all six.

## What score_summary returns

One row per scale question (Typeform types `nps`, `opinion_scale` and `rating`) per
month, with `answers`, `total_score` and `avg_score` on every row.

**NPS** (`promoters`, `passives`, `detractors`, `nps`) is filled for Typeform's NPS
question type only, which is always 0 to 10. Promoters score 9 or 10, passives 7 or
8, detractors 0 to 6, and `nps` is the share of promoters minus the share of
detractors, times 100. An opinion scale configured as 0 to 10 is not classified: the
model cannot tell it apart from any other 11-point scale.

**Top two box** (`top_two_box_answers`, `top_two_box_rate`) is the usual CSAT
definition: the share of answers in the top two points of the scale. The top of the
scale is read from the question's own settings (`steps`, and `start_at_one` for an
opinion scale). If those settings are missing, the rate is NULL rather than a guess.

## Notes

- **Roll up from counts, never from rates.** Every rate comes with the counts it was
  built from. A quarterly NPS is `100 * (SUM(promoters) - SUM(detractors)) /
  SUM(answers)`, not the average of three monthly NPS values, which would weight a
  quiet month the same as a busy one. The same goes for `avg_seconds_to_complete`:
  use `SUM(total_seconds_to_complete) / SUM(responses_with_duration)`.
- **Multi-select counts exceed respondents.** In `answer_detail` a respondent who
  ticks three options produces three rows. For "share of respondents who picked X",
  divide by `COUNT(DISTINCT response_token)`, as Typeform's Results page does.
- **`seconds_to_complete` has a long tail.** It is `submitted_at` minus `landed_at`,
  so a form left open in a tab for a day counts a day. The daily median is returned
  next to the mean for that reason.
- **Dates are UTC.** Typeform returns UTC timestamps and nothing here converts them.
  Typeform's UI shows your account's time zone, so a day's count can differ near
  midnight.
- **Hidden fields** stay a JSON string in `staging/response.sql`
  (`hidden_fields_json`), because their names are chosen per form. Extract the ones
  you use with `JSON_VALUE(hidden_fields_json, '$.utm_source')`.
- **Multi-account ready.** Every staging model emits a `typeform_account` label and
  it is part of every join key. To add an account, `UNION ALL` a second block in each
  staging model with a different label, and change nothing else.
- **Not run against a warehouse.** These models were checked for syntax and against
  the connector's schema, not executed on real data. Reconcile a month of responses
  and one NPS question against Typeform's Results page before relying on the output.

[Typeform Responses API](https://www.typeform.com/developers/responses/) ·
[Typeform question types](https://www.typeform.com/developers/create/reference/create-form/) ·
[Weld Typeform connector docs](https://weld.app/docs/applications/typeform)
