# Facebook Ads templates

SQL reports over Weld's Facebook Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/ad_report.sql`](weld/staging/ad_report.sql) · [dbt](dbt/models/staging/stg_facebook_ads__ad_report.sql) | Ad Report | Integrates with Facebook Ads and retrieves data from various tables such as ad_insight, account, campaign, ad_set, and ad. It selects specific columns from these tables and performs calculations to generate aggregated metrics such as spend, reach, impressions, clicks, CPC, CTR, and CPM. The template then joins these tables based on specific conditions and groups the results by certain columns. |
| [`weld/core/conversion_insights.sql`](weld/core/conversion_insights.sql) · [dbt](dbt/models/core/core_facebook_ads__conversion_insights.sql) | Conversion Insights | This SQL template retrieves conversion insights data from Facebook Ads, including various metrics such as spend, reach, impressions, clicks, and more. It joins data from different tables like ad_insight, ad, and ad_roas_insight_conversion_insights to provide a comprehensive analysis of ad performance. |
| [`weld/core/marketing_report.sql`](weld/core/marketing_report.sql) · [dbt](dbt/models/core/core_facebook_ads__marketing_report.sql) | Marketing Insights Dashboard | This SQL template consolidates advertising data from multiple platforms, including Facebook, Google, LinkedIn, TikTok, Snapchat, and Pinterest, into a unified dataset. It aggregates metrics such as clicks, impressions, spend, and conversions, and calculates performance indicators like CTR, CPC, CPM, and conversion rate. The result is grouped by date, platform, account, campaign, and ad identifiers for comprehensive marketing insights. |

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

- `staging/ad_report`: action values are summed per ad and day before the join. The website version joined one row per action type, so spend, clicks and impressions repeated once per action type.
- `core/marketing_report`: the stray `select` before the active block is gone, every commented platform block has its `select` and reads only columns that platform's ad report outputs, and IDs are cast to strings so the blocks union cleanly. LinkedIn campaign groups and creatives fill the campaign and ad columns; Snapchat's report has no campaign columns, so its block leaves them empty.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/ad_report` | `facebook_ads.ad_insight`, `facebook_ads.ad_roas_insight_action_values`, `facebook_ads.ad_roas_insight_conversion_insights`, `facebook_ads.ad`, `facebook_ads.creative` |
| `core/conversion_insights` | `facebook_ads.ad_insight`, `facebook_ads.ad_roas_insight_conversion_insights`, `facebook_ads.ad` |
| `core/marketing_report` | none · reads `staging.facebook_ads.ad_report`, `staging.google_ads.ad_report`, `staging.linkedin_ads.creative_report`, `staging.pinterest_ads.ad_report`, `staging.snapchat_ads.ad_report`, `staging.tiktok_ads.ad_report` |

## Models

### Ad Report

`weld/staging/ad_report.sql`

Provide insights and analytics on Facebook Ads data. By integrating with the
Facebook Ads platform, this SQL template retrieves data from various tables such as
ad_insight, account, campaign, ad_set, and ad.

### Conversion Insights

`weld/core/conversion_insights.sql`

"Conversion Insights" is designed to provide valuable insights from Facebook Ads
data integration. It retrieves various statistics related to ad performance, such as
spend, reach, impressions, clicks, and more. By joining different tables, it allows
for analyzing conversion insights by date, account, campaign, ad set, and ad levels.
This SQL can be useful for tracking the effectiveness of Facebook ad campaigns,
optimizing bidding strategies, and understanding user actions leading to
conversions.

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
