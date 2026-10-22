# Microsoft Ads templates

SQL reports over Weld's Microsoft Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/account_report.sql`](weld/core/account_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__account_report.sql) | Account Report | Generates an account report by integrating with Microsoft Ads. It retrieves data from the ad_performance_daily_report and account tables, joins them based on the account_id, and calculates metrics such as clicks, impressions, and spend. The resulting report includes information about the date, account name, account ID, time zone, device OS, device type, network, and currency code. |
| [`weld/core/ad_group_report.sql`](weld/core/ad_group_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__ad_group_report.sql) | Ad Group Report | Generates a report that combines data from the "ad_performance_daily_report," "ad_group," "campaign," and "account" tables in the Microsoft Ads integration. It joins these tables based on specific columns and calculates aggregated metrics such as clicks, impressions, and spend. The resulting report includes information on the date, account, campaign, ad group, device, network, and currency code. |
| [`weld/core/ad_report.sql`](weld/core/ad_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__ad_report.sql) | Ad Report | Generates an ad report by joining data from multiple tables related to Microsoft Ads. It retrieves information such as date, account name and ID, campaign name and ID, ad group name and ID, ad name and ID, device OS, device type, network, currency code, clicks, impressions, and spend. The template performs a left join on the specified tables and groups the data based on selected columns. The final result includes all columns from the joined data. |
| [`weld/core/campaign_report.sql`](weld/core/campaign_report.sql) · [dbt](dbt/models/core/core_microsoft_ads__campaign_report.sql) | Campaign Report | Generates a campaign report by integrating with Microsoft Ads. It combines data from the campaign performance daily report, campaign, and account tables. The joined table includes information such as date, account name and ID, campaign name and ID, campaign type and status, device OS and type, network, currency code, clicks, impressions, and spend. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

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

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/ad_report`: `ads.title ad_name` is selected twice, and BigQuery rejects duplicate column names when it materialises the model.
