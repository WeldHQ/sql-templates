# Zigpoll templates

Response volume, answer distributions, scores and post-purchase attribution from
Weld's Zigpoll connector. BigQuery, UTC.

Weld connector: **Zigpoll** ([docs](https://weld.app/docs/applications/zigpoll)).

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/response_volume.sql`](weld/core/response_volume.sql) · [dbt](dbt/models/core/core_zigpoll__response_volume.sql) | How many answers and respondents each poll gets | day × account × poll |
| [`weld/core/answer_detail.sql`](weld/core/answer_detail.sql) · [dbt](dbt/models/core/core_zigpoll__answer_detail.sql) | What people answered, option by option | account × response × selected option (× matrix row) |
| [`weld/core/score_summary.sql`](weld/core/score_summary.sql) · [dbt](dbt/models/core/core_zigpoll__score_summary.sql) | Average rating, and NPS on 0 to 10 scales | month × account × poll × slide |
| [`weld/core/attribution_by_answer.sql`](weld/core/attribution_by_answer.sql) · [dbt](dbt/models/core/core_zigpoll__attribution_by_answer.sql) | Orders and revenue behind each answer to a post-purchase question | month × account × poll × slide × answer × currency |

## Read this first: what this connector cannot do

**1. A "response" is one answer to one question.** Zigpoll stores a response per
participant per slide (question). A participant who answers four questions produces
four rows. `response_volume` therefore returns both `answers` (rows) and
`respondents` (distinct participants), and the two are different numbers by design.
`respondents` is a distinct count: it cannot be summed across days.

**2. Views and completions have no dates.** Zigpoll's render, open, engagement and
completion figures arrive only as lifetime counters on `poll` and `slide`, as of the
last sync. There is no daily participation or completion rate to build; divide
lifetime answers by `poll.open_count` at poll level if you need a rate.

**3. There is no NPS question type.** An NPS question in Zigpoll is a `range` slide
with options 0 to 10. `score_summary` classifies a slide as NPS only when its options
are exactly the whole numbers 0 to 10; every other rating scale gets an average and no
NPS.

**4. The response display string counts combinations.** `response_text` compiles
every option a participant picked into one string. Counting on it splits "Instagram,
TikTok" from "Instagram". Count options from `answer_detail.answer_value`, which comes
from the unnested option rows.

## Layers

```
raw.zigpoll.*          ELT output, untouched
  ↓
weld/staging/*.sql     5 thin wrappers: cast, rename, dedupe
  ↓
weld/core/*.sql        the reports, all the business logic lives here
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

**Staging** casts, renames and keeps the latest copy of each row, and picks the
Shopify order and UTM fields off the response so core does not have to.

**Core** holds the unnesting, the scale detection, the NPS buckets and the
attribution. `score_summary` and `attribution_by_answer` read `answer_detail`, so all
three agree on what an answer is. This is the layer worth reviewing.

**Analytics** exists for indirection, not transformation. Bind dashboards and
reverse-ETL syncs to `analytics.zigpoll.attribution_by_answer` so core stays free to
be renamed or re-grained. All four are `SELECT *`, and that is the point.

`dbt/` holds the same models with dbt refs, generated from the Weld versions so the
two cannot disagree. See [dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) a push deploys
all of them and Weld resolves the dependency order. Weld references map to folder
paths, so `{{staging.zigpoll.response}}` expects the model in a `staging > zigpoll`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| response volume | `response`, `poll` |
| answer detail | `response`, `response_answer`, `slide`, `poll` |
| score summary | the same, plus `slide_answer` |
| attribution by answer | the same as answer detail |

`response_answer` is a table of the `response` stream and `slide_answer` a table of
the `slide` stream.

## What attribution_by_answer returns

For every answer option on a question asked after checkout, the number of distinct
orders and their total `order_value`, per month and currency. This is the "how did
you hear about us" report: which channel buyers credit, weighted by what they spent.

- **Currency is in the grain.** `order_value` is in the order's own currency, and
  summing across currencies gives a meaningless number. Convert downstream if you need
  one total.
- **Multi-select answers count in full under every option picked.** Each row is right
  on its own, but the rows of a multi-select slide add up to more than total revenue.
  On a single-choice slide they add up exactly.
- **Only responses with a Shopify order id are counted.** Polls shown outside the
  thank-you or order status page carry no order and do not appear.

## Notes

- **Synthetic polls are excluded** from `response_volume`, `score_summary` and
  `attribution_by_answer`. `answer_detail` keeps them, flagged with `is_synthetic`.
- **NPS is computed from counts.** Promoters score 9 or 10, passives 7 or 8,
  detractors 0 to 6; `nps` is the share of promoters minus the share of detractors,
  times 100. Roll a quarter up from the summed counts, never by averaging monthly NPS.
- **Matrix answers may be incomplete.** Option rows are keyed on the option handle
  within a response. On a matrix where a respondent picks the same column for
  two rows, check one response against Zigpoll before relying on matrix counts.
- **Dates are UTC.** Zigpoll's dashboard may show your local time, so a day's count can
  differ near midnight.
- **History is limited to the sync start.** The first sync reads two years of
  responses by default.
- **Multi-account ready.** Every staging model emits a `zigpoll_account` label and it is
  part of every join key. To add an account, `UNION ALL` a second block in each staging
  model with a different label, and change nothing else.
- **Not run against a warehouse.** These models were checked for syntax and against the
  connector's schema, not executed on real data. Reconcile one poll's answer counts
  against its Zigpoll results page, and one month of attributed revenue against
  Shopify, before relying on the output.

[Zigpoll API reference](https://apidocs.zigpoll.com/) ·
[Zigpoll API guide](https://docs.zigpoll.com/api) ·
[Weld Zigpoll connector docs](https://weld.app/docs/applications/zigpoll)
