# Amazon Ads templates

SQL reports over Weld's Amazon Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/ad_group_report.sql`](weld/core/ad_group_report.sql) · [dbt](dbt/models/core/core_amazon_ads__ad_group_report.sql) | Ad Group Report | This template extracts a comprehensive breakdown of advertising performance on Amazon, grouped by ad groups for sponsored products. It integrates data from the sponsored product ad group report with the profile and ad group tables to deliver metrics like cost, clicks, and impressions for each ad group. |
| [`weld/core/ad_report.sql`](weld/core/ad_report.sql) · [dbt](dbt/models/core/core_amazon_ads__ad_report.sql) | Ad Report | This template extracts a comprehensive breakdown of advertising performance on Amazon, grouped by product ads for sponsored products. It integrates data from the sponsored product product ad report with the profile and ad tables to deliver metrics like cost, clicks, and impressions for each product ad. |
| [`weld/core/campaign_report.sql`](weld/core/campaign_report.sql) · [dbt](dbt/models/core/core_amazon_ads__campaign_report.sql) | Campaign Report | Extracts a comprehensive report of advertising performance for Amazon's Sponsored Products, grouped by campaigns and accounts. This report integrates data from the campaign report with the account and campaign tables to provide metrics such as cost, clicks, and impressions for each campaign. |
| [`weld/core/keyword_report.sql`](weld/core/keyword_report.sql) · [dbt](dbt/models/core/core_amazon_ads__keyword_report.sql) | Keyword Report | This template extracts a comprehensive breakdown of advertising performance on Amazon, grouped by keywords for sponsored products. It integrates data from the sponsored product keyword report with the profile and keyword tables to deliver metrics like cost, clicks, and impressions for each keyword. |

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

- `core/ad_report` joins ads on `report.ad_id`; the website version's `ad.ad_id = ad.ad_id` matched every ad to every row. `ad_id` is now part of the grain, so rows are per product ad as described.

## Ported to the current schema

All four reports now read the version 3 sponsored products report tables that
current connections sync. The version 2 report tables they read before are no
longer synced.

- Each report reads its `_v3` table: `sponsored_product_campaign_report_v3`, `sponsored_product_ad_group_report_v3`, `sponsored_product_keyword_report_v3` and `sponsored_product_product_ad_report_v3`.
- The ad group report joins `sponsored_product_ad_group_v3` for the ad group name, the current ad group table.
- The version 3 report rows carry `profile_id`, so the profile is joined from the report row instead of through the entity table. Rows whose campaign, ad group, keyword or ad is missing from the entity table now keep their account details.
- Entity tables are joined on their id and `profile_id`. When the entity row is missing, the name comes from the report row (`campaign_name`, `ad_group_name`, `keyword`, `advertised_asin`).
- `date` is returned as a `DATE`; the version 3 tables store it as a string.
- `core/ad_group_report` adds `ad_group_id` and `core/keyword_report` adds `keyword_id`, so two ad groups or keywords with the same name in one campaign stay apart. `core/ad_report` adds `asin`.
- The version 3 campaign report can hold more than one row per campaign and day, one per applicable budget rule, and the advertised product report splits an ad by advertised ASIN. The reports sum over these rows, as before.

## Required tables

| Model | Raw tables |
|---|---|
| `core/ad_group_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_ad_group_report_v3`, `amazon_ads.sponsored_product_ad_group_v3` |
| `core/ad_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_product_ad_report_v3`, `amazon_ads.sponsored_product_product_ad` |
| `core/campaign_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_campaign_report_v3`, `amazon_ads.sponsored_product_campaign` |
| `core/keyword_report` | `amazon_ads.profile`, `amazon_ads.sponsored_product_keyword_report_v3`, `amazon_ads.sponsored_product_keyword` |

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
