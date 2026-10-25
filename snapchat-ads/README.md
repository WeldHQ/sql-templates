# Snapchat Ads templates

Daily ad, ad squad and campaign performance from Snapchat Ads, in the same shape as
the other paid ads templates in this repo. BigQuery.

Weld connector: **Snapchat Ads** ([docs](https://weld.app/docs/applications/snapchat-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_snapchat_ads__ad_performance_daily.sql) | Ads Manager, Ads view, by day | day × ad account × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_snapchat_ads__campaign_performance_daily.sql) | Ads Manager, Campaigns view, by day, with swipe up rate, cost per swipe up, CPM, cost per purchase and ROAS | day × ad account × campaign |
| [`weld/core/ad_squad_performance_daily.sql`](weld/core/ad_squad_performance_daily.sql) · [dbt](dbt/models/core/core_snapchat_ads__ad_squad_performance_daily.sql) | Ads Manager, Ad Sets view, by day, with optimisation goal, bid strategy and budget | day × ad account × ad squad |

Snapchat's hierarchy is ad account > campaign > ad squad > ad. All three reports are
built from the one ad level report, so they always add up to each other.

## Cross-channel contract

The first twelve columns of `ad_performance_daily` are `date_day, account_id,
account_name, campaign_id, campaign_name, ad_id, ad_name, spend, impressions,
clicks, conversions, conversion_value`, the same set the other paid ads templates
here emit. Select those twelve from each and `UNION ALL` them for a blended spend
report. The `source` and `currency` columns that follow tell the rows apart; convert
currencies before summing across accounts.

In Snapchat terms: `clicks` are **swipe ups**, `conversions` are **purchases** and
the ad set level is the **ad squad**.

## Layers

```
raw.snapchat_ads.*        ELT output, untouched
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

Weld references map to folder paths, so `{{staging.snapchat_ads.ad}}` expects the
model in a `staging > snapchat_ads` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_daily_report`, `ad`, `ad_squad`, `campaign`, `ad_account` |
| campaign performance daily | the same, through `ad_performance_daily` |
| ad squad performance daily | the same, through `ad_performance_daily` |

All five are standard streams of the connector; no custom report is needed.

## Notes

- **Money is in micros.** Snapchat returns spend, purchase value, budgets and bids
  in millionths of the ad account's currency. Staging divides by 1,000,000.
- **Conversions are purchases under Snapchat's default attribution.** The
  connector does not set an attribution window on the stats request, so Snapchat
  applies its defaults: 28 days after a swipe up and 1 day after a view, counted
  together. Purchases come from the Snap Pixel, the Conversions API and app
  events alike. If Ads Manager is set to other windows, its numbers will not
  match; set the same windows in the Ads Manager column settings when you
  reconcile. For a lead or install account, swap `purchase_conversions` for
  `app_installs` or another conversion column in core.
- **Days are the ad account's days.** The report stores the instant each day
  starts. For an account east of UTC that instant lies on the previous UTC date,
  so core converts it with the ad account's timezone. Do not take `DATE()` of the
  raw column.
- **Late restatements are not re-read.** Snapchat finalises delivery metrics about
  48 hours after the day ends and keeps adding late conversions after that. The
  connector reads each day once more on the first sync after the day closes, then
  moves on. The last two or three days can therefore stay slightly below Ads
  Manager. A periodic full resync of `ad_daily_report` closes the gap.
- **Ads missing from the entity streams keep their spend.** Entity tables are
  joined with `LEFT JOIN` on account and id, so such ads count, with NULL names and
  a NULL campaign.
- **Names and settings are the current ones.** The entity streams keep one version
  per id, so a renamed campaign shows its new name on every past day, and
  `daily_budget` on the ad squad report is today's budget.
- **Several ad accounts.** Every join includes `account_id`, so syncing several ad
  accounts, or several organisations, into the same tables works without changes.
- **Not run against a warehouse.** These models were checked for syntax, references
  and column names only. Reconcile a week of spend, impressions, swipe ups and
  purchases per campaign against Ads Manager (same timezone, same attribution
  windows) before relying on the output.

## Schema notes

The public ERD and the connector's stream definitions agree for every column used
here. The report's `date` column is a timestamp (the start of the account's day),
not a calendar date. `conversion_signups` exists in the table but is not requested
by the connector, so it is always NULL; it is not used.

## Vendor docs

- Snapchat Marketing API, Measurement (stats, attribution windows, micro-currency): <https://developers.snap.com/api/marketing-api/Ads-API/measurement>
- Snapchat Marketing API reference: <https://developers.snap.com/api/marketing-api/Ads-API/introduction>
