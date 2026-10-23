# LinkedIn Ads templates

SQL reports over Weld's LinkedIn Ads connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/staging/creative_report.sql`](weld/staging/creative_report.sql) · [dbt](dbt/models/staging/stg_linkedin_ads__creative_report.sql) | Creative Report | Daily delivery per creative, labelled with campaign, campaign group and ad account: impressions, clicks, spend, conversions, conversion value, CTR, CPC and CPM. The LinkedIn input to the cross-channel marketing reports. |

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

- `staging/creative_report` was rewritten from the raw tables. CPC, CTR and CPM are now worked out from each day's totals; the website version added up per-row ratios.
- It now outputs `creative_name` (the creative's title), `creative_status` and `conversion_value`, which the cross-channel marketing reports in `google-ads/` and `facebook-ads/` read. The creative created and modified timestamps are no longer output.

## Required tables

| Model | Raw tables |
|---|---|
| `staging/creative_report` | `linkedin_ads.account`, `linkedin_ads.ad_analytics_by_creative`, `linkedin_ads.campaign_group`, `linkedin_ads.campaign`, `linkedin_ads.creative` |

## Models

### Creative Report

`weld/staging/creative_report.sql`

Daily LinkedIn Ads delivery per creative, read from the creative analytics
table and labelled with the creative's campaign, campaign group and ad account.
Rates are worked out from each day's totals, in the ad account's currency.
