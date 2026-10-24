# Pinterest Ads templates

SQL reports over Weld's Pinterest Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_pinterest_ads__ad_report.sql) | Ad Report | Generates an ad report for the Pinterest Ads integration. It retrieves data from multiple tables, including ad reports, ad accounts, campaigns, and ads. The report includes information such as date, account name and ID, campaign name and ID, ad name, status, type, created time, spend, impressions, clicks, CPC, CTR, CPM, and total conversions. The data is grouped by various columns for analysis. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that other templates read as a `{{staging...}}` ref sit in
  `weld/staging/`, so those refs resolve.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Corrected in review:

- `staging/ad_report` joins ads on `report.ad_id`; the website version used the ad group ID, so ad names and statuses came out wrong or empty.
- It also reads the campaign ID and name from the report (the website version output an empty `campaign_name`), takes the account ID from the report, and counts clicks as pin clicks (`total_clickthrough`) rather than total engagement, which also counts saves and closeups.

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
