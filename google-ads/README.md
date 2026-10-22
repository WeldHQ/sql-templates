# Google Ads templates

SQL reports over Weld's Google Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_google_ads__ad_report.sql) | Ad Report | Generates an ad report by joining data from various tables in the Google Ads integration. It retrieves information such as date, account ID and name, campaign name and ID, ad group name and ID, ad ID and name, ad status and type, display URL, final URLs, spend, impressions, clicks, CPC, CTR, CPM, and conversions. Additional columns can be manually specified if needed. |
| [`weld/core/ad_stats_by_country_monthly.sql`](weld/core/ad_stats_by_country_monthly.sql) · [dbt](dbt/models/core/core_google_ads__ad_stats_by_country_monthly.sql) | Ad stats by country monthly | Generates monthly ad statistics by country, including spend, clicks, CPC, cost per conversion, CTR, conversions, conversion value, impressions, and interactions, using data from Google Ads. It groups the data by month and country criterion ID. |
| [`weld/core/marketing_report.sql`](weld/core/marketing_report.sql) · [dbt](dbt/models/core/core_google_ads__marketing_report.sql) | Marketing Insights Dashboard | This SQL template consolidates advertising data from multiple platforms, including Facebook, Google, LinkedIn, TikTok, Snapchat, and Pinterest, into a unified dataset. It aggregates metrics such as clicks, impressions, spend, and conversions, and calculates performance indicators like CTR, CPC, CPM, and conversion rate. The result is grouped by date, platform, account, campaign, and ad identifiers for comprehensive marketing insights. |
| [`weld/core/url_report.sql`](weld/core/url_report.sql) · [dbt](dbt/models/core/core_google_ads__url_report.sql) | URL Report | Generates a report for URL performance in Google Ads. It retrieves data from various tables, including ad stats, accounts, campaigns, ad groups, and ads. The template calculates metrics such as spend, impressions, clicks, CPC, CTR, CPM, and conversions. Additional columns can be specified manually if needed. |

## Where these come from

These are the templates from the weld.app template library, moved here
unchanged apart from the notes below. Each one was published as a single query
rather than a layered model set, so:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Queries that other templates read as a `{{staging...}}` ref sit in
  `weld/staging/`, so those refs resolve.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

- The cross-channel marketing report expects the other platforms' ad reports at
  `{{staging.pinterest_ads.ad_report}}` and `{{staging.snapchat_ads.ad_report}}`; the
  website version said `staging.pinterest` and `staging.snapchat`, which match no
  folder here. Only the active platform's block is uncommented; uncomment the others
  once their ad reports are deployed.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/ad_report` | `google_ads.ad_stats` |
| `core/ad_stats_by_country_monthly` | `google_ads.ad_group_country_stats` |
| `core/marketing_report` | none · reads `staging.facebook_ads.ad_report`, `staging.google_ads.ad_report`, `staging.linkedin_ads.creative_report`, `staging.pinterest_ads.ad_report`, `staging.snapchat_ads.ad_report`, `staging.tiktok_ads.ad_report` |
| `core/url_report` | `google_ads.account`, `google_ads.ad_group`, `google_ads.ad_stats`, `google_ads.ad`, `google_ads.campaign` |

## Models

### Ad Report

`weld/staging/ad_report.sql`

Retrieve data from the Google Ads integration. It consists of several common table
expressions (CTEs) that extract data from different tables within the Google Ads
database. These CTEs include "stats," "accounts," "campaigns," "ad_groups," and
"ads."

### Ad stats by country monthly

`weld/core/ad_stats_by_country_monthly.sql`

This SQL model allows you to view ad statistics by country on a monthly basis. The
SQL code selects data from the Google Ads ad group country stats table and groups it
by month, country criterion ID, and spend. The resulting output provides valuable
insights into the performance of your ads, including the number of clicks, cost per
click (CPC), cost per conversion, click-through rate (CTR), conversions, conversion
value, impressions, and interactions. This information can be used to optimize your
ad campaigns and improve your return on investment (ROI). Whether you're a small
business owner or a marketing professional, the Ad stats by country monthly SQL
template is an essential tool for maximizing the effectiveness of your Google Ads
campaigns.

### Marketing Insights Dashboard

`weld/core/marketing_report.sql`

The "Marketing Insights" SQL model aggregates advertising data from multiple
platforms including Facebook, Google, LinkedIn, TikTok, Snapchat, and Pinterest. It
consolidates metrics such as clicks, impressions, spend, conversions, and conversion
value across these platforms into a unified dataset. This model calculates key
performance indicators (KPIs) like click-through rate (CTR), cost per click (CPC),
cost per thousand impressions (CPM), and conversion rate, providing a comprehensive
view of marketing performance. By using this SQL model, marketers can gain valuable
insights into the effectiveness of their campaigns, compare performance across
different platforms, and optimize their advertising strategies for better ROI.

### URL Report

`weld/core/url_report.sql`

Retrieve data from the Google Ads integration. It combines multiple tables, such as
ad_stats, account, campaign, ad_group, and ad, to generate a comprehensive report on
URL performance.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/marketing_report`: a stray `select` before the Google block (line ~22) is a syntax error. The commented Facebook block is missing its `select`, and the LinkedIn and Snapchat blocks reference columns those reports don't output.
- `core/ad_stats_by_country_monthly`: `group by 1, 2, 3` includes an aggregate (`spend`), which BigQuery rejects. CPC, cost per conversion and CTR add up per-row ratios rather than dividing totals.
- `core/url_report`: CPC, CTR and CPM add up per-row ratios rather than dividing totals.
- `staging/ad_report`: `roas` is cost divided by conversion value, the inverse of ROAS.
