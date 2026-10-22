# Snapchat Ads templates

SQL reports over Weld's Snapchat Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_snapchat_ads__ad_report.sql) | Ad Report | Generates an ad report by integrating with Snapchat Ads. It retrieves data from various tables such as ad_daily_report, campaign, ad_account, and ad. The report includes information such as date, account ID and name, campaign ID and name, ad ID and name, currency, spend, impressions, clicks, CPC, CTR, CPM, and conversions. The data is filtered based on the date and grouped by different columns. |

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
| `staging/ad_report` | `snapchat_ads.ad_account`, `snapchat_ads.ad_daily_report`, `snapchat_ads.ad`, `snapchat_ads.creative` |

## Models

### Ad Report

`weld/staging/ad_report.sql`

Combines data from multiple tables, including ad_daily_report, campaign, ad_account,
and ad, to generate a comprehensive report.
