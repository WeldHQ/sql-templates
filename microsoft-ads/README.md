# Microsoft Ads templates

SQL reports over Weld's Microsoft Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/account_report.sql`](weld/core/account_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__account_report.sql) | Account Report | Daily delivery per ad account, split by device OS, device type and network: impressions, clicks, spend, conversions and revenue, with the account name and time zone. |
| [`weld/core/ad_group_report.sql`](weld/core/ad_group_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__ad_group_report.sql) | Ad Group Report | Daily delivery per ad group, split by device OS, device type and network, labelled with campaign and account: impressions, clicks, spend, conversions and revenue. |
| [`weld/core/ad_report.sql`](weld/core/ad_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__ad_report.sql) | Ad Report | Daily delivery per ad, split by device OS, device type and network, labelled with ad group, campaign and account: impressions, clicks, spend, conversions and revenue. |
| [`weld/core/campaign_report.sql`](weld/core/campaign_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__campaign_report.sql) | Campaign Report | Daily delivery per campaign, split by device OS, device type and network, with campaign type and status: impressions, clicks, spend, conversions and revenue. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Corrected in review:

- All four reports were rewritten from the raw tables. Report metrics are summed at the report's grain before account, campaign, ad group and ad names are looked up, and Microsoft's conversions and revenue are included.
- `core/ad_report` selected `ad_name` twice, which BigQuery rejects; it now appears once.

## Required tables

| Model | Raw tables |
|---|---|
| `core/account_report` | `microsoft_ads.account`, `microsoft_ads.ad_performance_daily_report` |
| `core/ad_group_report` | `microsoft_ads.account`, `microsoft_ads.ad_group`, `microsoft_ads.ad_performance_daily_report`, `microsoft_ads.campaign` |
| `core/ad_report` | `microsoft_ads.account`, `microsoft_ads.ad_group`, `microsoft_ads.ad_performance_daily_report`, `microsoft_ads.ad`, `microsoft_ads.campaign` |
| `core/campaign_report` | `microsoft_ads.account`, `microsoft_ads.campaign_performance_daily_report`, `microsoft_ads.campaign` |

## Models

### Account Report

`weld/core/account_report.sql`

Generates a report that combines data from two tables:
`microsoft_ads.ad_performance_daily_report` and `microsoft_ads.account`. This
template is useful for analyzing and gaining insights into the performance of
Microsoft Ads accounts.

### Ad Group Report

`weld/core/ad_group_report.sql`

Retrieves data from the Microsoft Ads platform. It combines data from multiple
tables including ad_performance_daily_report, ad_group, campaign, and account. The
template uses common table expressions (CTEs) to organize the data retrieval
process.

### Ad Report

`weld/core/ad_report.sql`

Retrieves data from the Microsoft Ads integration. It combines multiple tables,
including ad_performance_daily_report, ad, ad_group, campaign, and account, to
generate a comprehensive report on ad performance.

### Campaign Report

`weld/core/campaign_report.sql`

Generates a report on campaign performance using data from the Microsoft Ads
integration. This SQL model combines data from three tables:
campaign_performance_daily_report, campaign, and account.
