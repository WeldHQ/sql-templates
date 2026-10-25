# Google Ads templates

Daily ad, campaign, country and landing page performance from Google Ads, in the
same shape as the other paid ads templates in this repo. BigQuery.

Weld connector: **Google Ads** ([docs](https://weld.app/docs/applications/google-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_google_ads__ad_performance_daily.sql) | Ads view, by day, with final URL and effective URL suffix | day × account × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_google_ads__campaign_performance_daily.sql) | Campaigns view, by day, with CTR, CPC, CPM, cost per conversion and ROAS | day × account × campaign |
| [`weld/core/country_performance_daily.sql`](weld/core/country_performance_daily.sql) · [dbt](dbt/models/core/core_google_ads__country_performance_daily.sql) | Locations, user locations report, by day and campaign | day × account × campaign × country × location type |
| [`weld/core/landing_page_performance_daily.sql`](weld/core/landing_page_performance_daily.sql) · [dbt](dbt/models/core/core_google_ads__landing_page_performance_daily.sql) | Landing pages, by day and campaign | day × account × campaign × landing page |

## Cross-channel contract

`ad_performance_daily` and `campaign_performance_daily` both start with
`date_day, account_id, account_name, currency, campaign_id, campaign_name`, then
(ad model only) `ad_group_id, ad_group_name, ad_id, ad_name`, then `spend,
impressions, clicks, conversions, conversion_value, ctr, cpc, cpm,
cost_per_conversion, roas`. The other paid ads templates here emit the same
columns, so select them from each and `UNION ALL`. `account_id` is part of every
join key, so several Google Ads accounts in one schema stay apart. Convert
currencies before summing across accounts.

For a cross-channel spend total, stack the campaign models, not the ad models:
Google's ad level report does not cover every campaign type (see Notes).

## Layers

```
raw.google_ads.*          ELT output, untouched
  ↓
weld/staging/*.sql        8 thin wrappers: cast, convert micros, drop retracted rows, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.google_ads.ad}}` expects the model
in a `staging > google_ads` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_stats`, `ad`, `ad_group`, `campaign`, `account` |
| campaign performance daily | `campaign_stats`, `campaign`, `account` |
| country performance daily | `ad_group_country_stats`, `geo_target`, `campaign`, `account` |
| landing page performance daily | the same as ad performance daily, through that model |

All are standard streams of the connector; enable them in the sync settings.

## Notes

- **Money is in micros.** Google returns cost as millionths of the account
  currency; staging divides by 1,000,000. Conversion value is already in currency.
- **account_id is the Google Ads customer ID,** digits only, no dashes. Under a
  manager account each client account syncs with its own ID.
- **Conversions are Google's "Conversions" column:** conversion actions marked as
  primary, each under its own attribution model and click-through window (set per
  conversion action in Google Ads, data-driven and 30 days by default). They are
  dated on the day of the click or interaction, not the day of the conversion,
  and can be fractional. View-through conversions are carried in their own column
  and are not included.
- **All conversions are not in the standard streams.** If you report on "All
  conv.", add `metrics.all_conversions` and `metrics.all_conversions_value` in a
  custom report and swap them in.
- **Late conversions and retractions.** The connector re-reads the last 30 days of
  each report once a day. Rows Google no longer returns for that window (for
  example after invalid click credits) are marked deleted, and staging drops them.
  Conversions that arrive more than 30 days after the click are not picked up.
- **Ad level is not account level.** Performance Max, Smart and some App campaigns
  report no ad rows, so `ad_performance_daily` and the landing page and country
  models sum to less than `campaign_performance_daily` in accounts that run them.
  The campaign model reads the campaign report for that reason.
- **Country rows are split by location type.** Google reports a user's country as
  either where they were (`LOCATION_OF_PRESENCE`) or what they searched for
  (`AREA_OF_INTEREST`). Both stay in the grain; filter to one, or check the total
  against the campaign model before adding them up.
- **Dates are in the account's time zone,** as Google reports them.
- **Names are the current ones.** Entity streams are re-read in full, so a renamed
  campaign shows its new name on every past day. Removed entities fall back to the
  name carried on the report row.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, clicks and conversions per campaign
  against the Google Ads UI (same date range, same columns) before relying on the
  output.

## Schema notes

The ERD and the connector's stream definitions agree on every table and column
these models read. The ERD does not list `_weld_deleted_at` on the entity tables;
these models only read it on the report tables, where both list it.

## Vendor docs

- Google Ads API, metrics: <https://developers.google.com/google-ads/api/fields/latest/metrics>
- Google Ads API, ad group ad report: <https://developers.google.com/google-ads/api/fields/latest/ad_group_ad>
- Google Ads API, geographic view: <https://developers.google.com/google-ads/api/fields/latest/geographic_view>
- About conversion measurement: <https://support.google.com/google-ads/answer/1722022>
