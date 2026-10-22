# TikTok Ads templates

SQL reports over Weld's TikTok Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_tiktok_ads__ad_report.sql) | Ad Report | Generates an ad report by joining multiple tables from the TikTok Ads integration. It retrieves data such as impressions, clicks, spend, reach, conversions, likes, comments, shares, and various video metrics for each ad group. The report also includes information about the advertiser, campaign, account, currency, gender, audience type, and budget. |

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
| `staging/ad_report` | `tiktok_ads.ad_daily_report`, `tiktok_ads.ad_group`, `tiktok_ads.ad`, `tiktok_ads.advertiser`, `tiktok_ads.campaign` |

## Models

### Ad Report

`weld/staging/ad_report.sql`

Retrieves data from the TikTok Ads integration. It combines multiple tables,
including ad_daily_report, ad, ad_group, advertiser, and campaign, to generate a
comprehensive report on ad performance.
