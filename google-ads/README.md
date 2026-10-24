# Google Ads templates

SQL reports over Weld's Google Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_google_ads__ad_report.sql) | Ad Report | Generates an ad report by joining data from various tables in the Google Ads integration. It retrieves information such as date, account ID and name, campaign name and ID, ad group name and ID, ad ID and name, ad status and type, display URL, final URLs, spend, impressions, clicks, CPC, CTR, CPM, and conversions. Additional columns can be manually specified if needed. |
| [`weld/core/ad_stats_by_country_monthly.sql`](weld/core/ad_stats_by_country_monthly.sql) · [dbt](dbt/models/core/core_google_ads__ad_stats_by_country_monthly.sql) | Ad stats by country monthly | Generates monthly ad statistics by country, including spend, clicks, CPC, cost per conversion, CTR, conversions, conversion value, impressions, and interactions, using data from Google Ads. It groups the data by month and country criterion ID. |
| [`weld/core/marketing_report.sql`](weld/core/marketing_report.sql) · [dbt](dbt/models/core/core_google_ads__marketing_report.sql) | Marketing Insights Dashboard | This SQL template consolidates advertising data from multiple platforms, including Facebook, Google, LinkedIn, TikTok, Snapchat, and Pinterest, into a unified dataset. It aggregates metrics such as clicks, impressions, spend, and conversions, and calculates performance indicators like CTR, CPC, CPM, and conversion rate. The result is grouped by date, platform, account, campaign, and ad identifiers for comprehensive marketing insights. |
| [`weld/core/url_report.sql`](weld/core/url_report.sql) · [dbt](dbt/models/core/core_google_ads__url_report.sql) | URL Report | Daily delivery per ad with its final URLs, display URL and UTM tags: impressions, clicks, spend, conversions, CTR, CPC and CPM, in the account currency. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

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

Corrected in review:

- `core/marketing_report`: the stray `select` before the active block is gone, every commented platform block has its `select` and reads only columns that platform's ad report outputs, and IDs are cast to strings so the blocks union cleanly. LinkedIn campaign groups and creatives fill the campaign and ad columns; Snapchat's report has no campaign columns, so its block leaves them empty.
- `core/ad_stats_by_country_monthly` groups by month and country only (the website version grouped by `spend`, an aggregate, which BigQuery rejects). CPC, cost per conversion and CTR divide the month's totals.
- `core/url_report` was rewritten from the raw tables. CPC, CTR and CPM divide each day's totals. Campaign and ad group names come from `ad_stats`, so it no longer reads the campaign and ad group tables, and it adds the account currency. The UTM patterns also match a tag at the very start of the final URL suffix, which has no leading `?` or `&`.
- `staging/ad_report`: `roas` is conversion value divided by spend; the website version divided spend by conversion value.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/ad_report` | `google_ads.ad_stats` |
| `core/ad_stats_by_country_monthly` | `google_ads.ad_group_country_stats` |
| `core/marketing_report` | none · reads `staging.facebook_ads.ad_report`, `staging.google_ads.ad_report`, `staging.linkedin_ads.creative_report`, `staging.pinterest_ads.ad_report`, `staging.snapchat_ads.ad_report`, `staging.tiktok_ads.ad_report` |
| `core/url_report` | `google_ads.account`, `google_ads.ad_stats`, `google_ads.ad` |

## Models

### Ad Report

`weld/staging/ad_report.sql`

Retrieve data from the Google Ads integration. It consists of several common table
expressions (CTEs) that extract data from different tables within the Google Ads
database. These CTEs include "stats," "accounts," "campaigns," "ad_groups," and
"ads."

### Ad stats by country monthly

`weld/core/ad_stats_by_country_monthly.sql`

Monthly ad statistics by country from the Google Ads ad group country stats
table: spend, clicks, impressions, interactions, conversions and conversion
value, with CPC, cost per conversion and CTR worked out from the month's totals.
Countries are Google geo target IDs.

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

Ties Google Ads delivery to landing pages. Each row is one ad on one day, with
its final URLs and the UTM tags read from its final URL suffix, falling back to
google / cpc / campaign name / ad group name where a tag is missing.
