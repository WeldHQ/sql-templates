# Pinterest Ads templates

SQL reports over Weld's Pinterest Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_pinterest_ads__ad_report.sql) | Ad Report | Generates an ad report for the Pinterest Ads integration. It retrieves data from multiple tables, including ad reports, ad accounts, campaigns, and ads. The report includes information such as date, account name and ID, campaign name and ID, ad name, status, type, created time, spend, impressions, clicks, CPC, CTR, CPM, and total conversions. The data is grouped by various columns for analysis. |

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
| `staging/ad_report` | `pinterest_ads.ad_account`, `pinterest_ads.ad_report`, `pinterest_ads.ad` |

## Models

### Ad Report

`weld/staging/ad_report.sql`

Generate a comprehensive report on advertising performance using data from the
Pinterest Ads integration. This SQL model combines data from multiple tables,
including ad reports, ad accounts, campaigns, and ads, to provide insights into
various metrics related to ad performance.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `staging/ad_report`: the ad join uses `report.ad_group_id = ad.id`; it should be `report.ad_id`.
