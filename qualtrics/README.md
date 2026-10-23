# Qualtrics templates

Response volume, answer distributions, NPS and email distribution performance from
Weld's Qualtrics connector. BigQuery, UTC.

Weld connector: **Qualtrics** ([docs](https://weld.app/docs/applications/qualtrics)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/response_volume.sql`](weld/core/response_volume.sql) · [dbt](dbt/models/core/core_qualtrics__response_volume.sql) | How many responses each survey records, finished or not, by channel, how long they take and how far abandoners get | day × account × survey |
| [`weld/core/answer_detail.sql`](weld/core/answer_detail.sql) · [dbt](dbt/models/core/core_qualtrics__answer_detail.sql) | What people answered, question by question | account × response × question × matrix row × selected value |
| [`weld/core/nps_by_month.sql`](weld/core/nps_by_month.sql) · [dbt](dbt/models/core/core_qualtrics__nps_by_month.sql) | Net Promoter Score per NPS question | month × account × survey × question |
| [`weld/core/distribution_performance.sql`](weld/core/distribution_performance.sql) · [dbt](dbt/models/core/core_qualtrics__distribution_performance.sql) | Sent, opened, started, finished per email distribution | account × distribution |

## Read this first: what this connector cannot do

**1. Responses in progress are not synced.** The connector uses Qualtrics' response
export, which returns recorded responses: finished ones, and unfinished ones Qualtrics
has closed and recorded. Someone halfway through the survey right now is not in the
data. So `finish_rate` in `response_volume` is the share of *recorded* responses that
were finished, not the share of people who started. The only start counts available
are on email distributions, in `distribution_performance`.

**2. Distribution stats are snapshots.** `stats_sent`, `stats_opened`,
`stats_started` and `stats_finished` are Qualtrics' running totals for each
distribution, not events. The connector re-reads the last week of distributions once
a day. A distribution older than that keeps the totals it had when last read, so a
late trickle of responses to an old invite shows in `response_volume` but not in
`distribution_performance`.

**3. Surveys and questions are their current definition.** `question` and
`sub_question` hold each survey as it is now. A reworded question shows the new
wording against every past answer; a deleted one leaves its answers with a NULL
`question_text`.

**4. Some answers are not synced.** The connector keeps an answer when its export
key is a question id, a question id plus a matrix row, or a text-entry question's
text. Three kinds of answer have other keys and are not in `question_response`:
answers inside a Loop & Merge block (prefixed with the loop number), the free
text typed into an "Other, please specify" choice, and Qualtrics' own computed
NPS group. The NPS group is recomputed from the score in `nps_by_month`; the
other two cannot be rebuilt.

**5. No per-recipient distribution history.** Qualtrics keeps a status per
recipient for each distribution (sent, opened, started, finished, bounced). The
connector syncs the distribution's totals, not that per-recipient table, so a
contact-level funnel ("who opened but did not start") cannot be built.

**6. Only email distributions are modelled.** SMS distributions are synced as a
separate stream, `sms_distribution`, with identical columns. To include them, add a
staging model over it and `UNION ALL` it into `distribution_performance` with a
channel label.

## Layers

```
raw.qualtrics.*          ELT output, untouched
  ↓
weld/staging/*.sql       6 thin wrappers: cast, rename, dedupe, decode response type
  ↓
weld/core/*.sql          the reports, all the business logic lives here
  ↓
weld/analytics/*.sql     BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps the latest copy of each row. It also decodes
Qualtrics' numeric response `status` into `response_type` and an `is_test_or_spam`
flag (previews, test responses, synthetic panel responses and the legacy spam
statuses), so core can exclude them from counts.

**Core** holds the joins, the NPS buckets, the funnel rates and the day spine. This is
the layer worth reviewing. `nps_by_month` reads `answer_detail`, so the two always
agree on what a response to an NPS question is.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.qualtrics.nps_by_month` so core stays free to be
renamed or re-grained. All four are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.qualtrics.survey_response}}` expects the model in a
`staging > qualtrics` folder. Mirror that structure in your synced repo, or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| response volume | `survey_response`, `survey` |
| answer detail | `question_response`, `survey_response`, `question`, `sub_question`, `survey` |
| NPS by month | the same as answer detail |
| distribution performance | `distribution`, `survey` |

`question_response` is a table of the `survey_response` stream, and `question` and
`sub_question` are tables of the `survey` stream.

## What answer_detail returns

One row per answer component, already in long format: the connector splits a
multi-select answer into one row per selected choice (`response_index` 0, 1, 2, ...)
and a matrix answer into one row per matrix row (`sub_question_key`, labelled by
`sub_question_text`).

Each row carries two versions of the answer. `response_value` is what Qualtrics
exports as the value: a choice's **recode** for a choice question, the typed text for
a text entry. `response_label` is the choice text the respondent saw. Group on the
label for display; do arithmetic on `response_number`, the value cast to a number.

Question ids (`QID1`, `QID2`, ...) repeat across surveys. Every join on a question
uses `survey_id` as well, taken from the response, because `question_response` itself
carries no survey id.

## Notes

- **NPS is computed from counts.** Promoters score 9 or 10, passives 7 or 8,
  detractors 0 to 6; `nps` is the share of promoters minus the share of detractors,
  times 100. Roll a quarter up as `100 * (SUM(promoters) - SUM(detractors)) /
  SUM(answers)`, never by averaging monthly NPS.
- **NPS scores are recodes.** Qualtrics' default recodes for an NPS question are 0 to
  10. A question whose recodes were edited produces wrong scores here and in Qualtrics'
  own NPS widget alike; `invalid_scores` and
  [`assert_qualtrics__nps_buckets_cover_every_answer`](dbt/tests/assert_qualtrics__nps_buckets_cover_every_answer.sql)
  surface it.
- **Roll distribution rates up from counts too.** Sum `finished` and `delivered`
  across distributions and divide. Reminders and thank-yous are their own rows, linked
  to the invite by `parent_distribution_id`; filter on `request_type = 'Invite'` when
  counting people invited.
- **Duration is for finished responses only.** An unfinished response's duration is
  how long it sat open before Qualtrics closed it.
- **Dates are UTC.** Qualtrics' UI shows your account's time zone, so a day's count
  can differ near midnight.
- **Embedded data** (`survey_embedded_data`, key/value per response) is synced but not
  modelled, because its keys are chosen per survey. Pivot the keys you segment on
  into `answer_detail` with a join on `response_id`.
- **Deletes are not captured** on the incremental streams. A response deleted in
  Qualtrics stays in your warehouse until the table is fully re-synced.
- **Test and preview responses are left out of every count** so a survey's
  numbers describe real respondents; `excluded_test_or_spam` shows how many were
  dropped. Duration is averaged over finished responses only.
- **Multi-account ready.** Every staging model emits a `qualtrics_account` label and
  it is part of every join key. To add an account, `UNION ALL` a second block in each
  staging model with a different label, and change nothing else.
- Metric definitions were cross-checked against Fivetran's open-source
  `dbt_qualtrics` package; the SQL here is written independently for Weld's
  schema.
- **Not run against a warehouse.** These models were checked for syntax and against
  the connector's schema, not executed on real data. Reconcile one survey's response
  count and NPS against its Results tab, and one distribution against the
  Distributions tab, before relying on the output.

[Qualtrics API](https://api.qualtrics.com/) ·
[Net Promoter Score](https://www.qualtrics.com/experience-management/customer/net-promoter-score/) ·
[Weld Qualtrics connector docs](https://weld.app/docs/applications/qualtrics)

Qualtrics' support article "Understanding your dataset" explains every column in a
response export, including the response type codes decoded in staging.
