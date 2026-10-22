# LinkedIn Ads templates

SQL reports over Weld's LinkedIn Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/creative_report.sql`](weld/staging/creative_report.sql) · [dbt](dbt/models/staging/stg_linkedin_ads__creative_report.sql) | Creative Report | Generate a report on LinkedIn Ads performance. It combines data from various tables such as creative, campaign, campaign_group, account, and report to provide insights on metrics like spend, impressions, clicks, CPC, CTR, and conversions. The template uses left joins to connect the tables based on their respective IDs and groups the data by specific columns for aggregation. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

- Queries that other templates read as a `{{staging...}}` ref sit in
  `weld/staging/`, so those refs resolve.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/creative_report` | `linkedin_ads.account`, `linkedin_ads.ad_analytics_by_creative`, `linkedin_ads.campaign_group`, `linkedin_ads.campaign`, `linkedin_ads.creative` |

## Models

### Creative Report

`weld/staging/creative_report.sql`

Designed to retrieve data from the LinkedIn Ads integration. It combines multiple
tables, including "creative," "campaign," "campaign_group," "account," and "report,"
to generate insightful reports on advertising performance.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `staging/creative_report`: CPC, CTR and CPM add up per-row ratios rather than dividing totals.
