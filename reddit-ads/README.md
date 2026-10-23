# Reddit Ads templates

Daily ad and campaign performance from Reddit Ads, in the same shape as the other
paid ads templates in this repo. BigQuery.

Weld connector: **Reddit Ads** ([docs](https://weld.app/docs/applications/reddit-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_reddit_ads__ad_performance_daily.sql) | Ads Manager, Ads tab, by day | day × ad account × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_reddit_ads__campaign_performance_daily.sql) | Ads Manager, Campaigns tab, by day, with CTR, CPC, CPM, cost per purchase and ROAS | day × ad account × campaign |

## Cross-channel contract

The first twelve columns of `ad_performance_daily` are `date_day, account_id,
account_name, campaign_id, campaign_name, ad_id, ad_name, spend, impressions,
clicks, conversions, conversion_value`, the same set the other paid ads templates
here emit. Select those twelve from each and `UNION ALL` them for a blended spend
report. The `source` and `currency` columns that follow tell the rows apart; convert
currencies before summing across accounts.

`conversions` here counts click-through and view-through purchases together. Many
cross-channel reports count click-through only; if yours does, use
`purchase_click_conversions` from the same model instead, so Reddit is not
credited with view-throughs that other channels leave out.

## Layers

```
raw.reddit_ads.*          ELT output, untouched
  ↓
weld/staging/*.sql        5 thin wrappers: cast, convert micros, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.reddit_ads.ad}}` expects the model
in a `staging > reddit_ads` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_performance` (custom report, see below), `ad`, `ad_group`, `campaign`, `ad_account` |
| campaign performance daily | the same, through `ad_performance_daily` |

### Set up the report

Performance data in the Weld Reddit Ads connector comes from custom reports: you
choose breakdowns and fields, and each report syncs as its own table named after
the report. Create one report with:

- **Name:** `ad_performance`
- **Breakdowns:** `AD_ID`, `DATE`
- **Fields:** `IMPRESSIONS`, `CLICKS`, `SPEND`, `CONVERSION_PURCHASE_CLICKS`,
  `CONVERSION_PURCHASE_VIEWS`, `CONVERSION_PURCHASE_TOTAL_VALUE`
- **Timezone:** the ad account's own timezone

If you name it differently, change the raw ref in `weld/staging/ad_performance.sql`.
Extra fields are harmless; missing ones make the staging model fail.

## Notes

- **Money is in micros.** Reddit returns spend as millionths of the account
  currency; staging divides by 1,000,000. Purchase value is converted the same way.
  Reddit's API reference does not state the unit for the value fields, and other
  tools that read this field disagree on it (whole currency units, cents or
  micros). Compare one day's purchase value with Ads Manager before relying on
  ROAS, and change the divisor in `weld/staging/ad_performance.sql` if it is off.
- **Every report column arrives as a string.** Staging casts with `SAFE_CAST`, so a
  malformed value becomes 0 rather than failing the run.
- **Conversions are purchases, click-through plus view-through,** under the
  attribution windows set on the ad account (`ad_account.click_attribution_window`,
  `view_attribution_window`). They are dated on the ad interaction and Reddit keeps
  updating them for days. The connector re-reads the previous day on every sync,
  which captures most, but not all, late conversions. For a lead or sign-up
  account, swap the purchase fields for `CONVERSION_LEAD_*` or `CONVERSION_SIGN_UP_*`
  in the report and in staging.
- **Report windows are UTC days.** Each report row covers one UTC day. With a
  non-UTC report timezone a local date spans two windows, so core sums across
  them. Do not filter staging to one window per date.
- **Report history starts at 1 June 2024,** the earliest date that is synced.
- **Deleted ads keep their spend.** Entity tables are joined with `LEFT JOIN`, so an
  ad missing from `ad` still counts, with NULL names and a NULL campaign.
- **Names are the current ones.** The ad, ad group and campaign streams are
  re-read in full and keep one version per id, so a renamed campaign shows its
  new name on every past day.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, impressions and clicks per campaign
  against Ads Manager (same timezone, same attribution windows) before relying on the
  output.

## Schema notes

The public ERD for this connector lists the entity tables only. The performance
table is a custom report whose name and columns depend on your setup, so it is not
in the ERD; its columns are the snake_cased Reddit API field names plus
`account_id`, `starts_at` and `ends_at`, which Weld adds.

## Vendor docs

- Reddit Ads API v3, Get a Report: <https://ads-api.reddit.com/docs/v3/operations/Get%20A%20Report>
- Reddit Ads API v3 reference: <https://ads-api.reddit.com/docs/v3/>
