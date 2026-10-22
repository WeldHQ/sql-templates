# Amazon Ads templates

SQL reports over Weld's Amazon Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/ad_group_report.sql`](weld/core/ad_group_report.sql) · [dbt](dbt/models/core/core_amazon_ads__ad_group_report.sql) | Ad Group Report | This template extracts a comprehensive breakdown of advertising performance on Amazon, grouped by ad groups for sponsored products. It integrates data from the sponsored product ad group report with the profile and ad group tables to deliver metrics like cost, clicks, and impressions for each ad group. |
| [`weld/core/ad_report.sql`](weld/core/ad_report.sql) · [dbt](dbt/models/core/core_amazon_ads__ad_report.sql) | Ad Report | This template extracts a comprehensive breakdown of advertising performance on Amazon, grouped by product ads for sponsored products. It integrates data from the sponsored product product ad report with the profile and ad tables to deliver metrics like cost, clicks, and impressions for each product ad. |
| [`weld/core/campaign_report.sql`](weld/core/campaign_report.sql) · [dbt](dbt/models/core/core_amazon_ads__campaign_report.sql) | Campaign Report | Extracts a comprehensive report of advertising performance for Amazon's Sponsored Products, grouped by campaigns and accounts. This report integrates data from the campaign report with the account and campaign tables to provide metrics such as cost, clicks, and impressions for each campaign. |
| [`weld/core/keyword_report.sql`](weld/core/keyword_report.sql) · [dbt](dbt/models/core/core_amazon_ads__keyword_report.sql) | Keyword Report | This template extracts a comprehensive breakdown of advertising performance on Amazon, grouped by keywords for sponsored products. It integrates data from the sponsored product keyword report with the profile and keyword tables to deliver metrics like cost, clicks, and impressions for each keyword. |

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
| `core/ad_group_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_ad_group_report`, `amazon_ads.sponsored_product_ad_group` |
| `core/ad_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_product_ad_report`, `amazon_ads.sponsored_product_product_ad` |
| `core/campaign_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_campaign_report`, `amazon_ads.sponsored_product_campaign` |
| `core/keyword_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_keyword_report`, `amazon_ads.sponsored_product_keyword` |

## Models

### Ad Group Report

`weld/core/ad_group_report.sql`

This SQL model offers a granular, daily snapshot of advertising activity on Amazon
related to sponsored products at the ad group level. By combining data from the
sponsored product ad group report with additional information from profile and ad
group tables, this template provides an extensive view of key metrics such as cost,
clicks, and impressions. Marketers can use this data to fine-tune their advertising
strategies and make informed decisions.

### Ad Report

`weld/core/ad_report.sql`

This SQL model offers a granular, daily snapshot of advertising activity on Amazon
related to sponsored products at the product ad level. By combining data from the
sponsored product product ad report with additional information from profile and ad
tables, this template provides an extensive view of key metrics such as cost,
clicks, and impressions. Marketers can use this data to fine-tune their advertising
strategies and make informed decisions.

### Campaign Report

`weld/core/campaign_report.sql`

This SQL model delivers a granular report of advertising activity on Amazon's
Sponsored Products at the campaign level. By combining insights from the campaign
report with details about specific accounts and campaigns, marketers receive a
complete view of metrics like cost, clicks, and impressions. This comprehensive
analysis assists in optimizing advertising strategies by highlighting the
performance of individual sponsored product campaigns.

### Keyword Report

`weld/core/keyword_report.sql`

This SQL model offers a granular, daily snapshot of advertising activity on Amazon
related to sponsored products at the keyword level. By combining data from the
sponsored product keyword report with additional information from profile and
keyword tables, this template provides an extensive view of key metrics such as
cost, clicks, and impressions. Marketers can use this data to fine-tune their
advertising strategies and make informed decisions.

## Known issues

Found while moving the templates here. The SQL is kept as published; fix these
before running the affected models.

- `core/ad_report`: the ad join is `on ad.ad_id = ad.ad_id`, which is always true, so every report row matches every ad and spend, clicks and impressions multiply. It should join on `report.ad_id`.
