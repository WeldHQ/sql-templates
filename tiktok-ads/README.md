# TikTok Ads templates

Daily ad, ad group and campaign performance from TikTok Ads, in the same shape as
the other paid ads templates in this repo. BigQuery.

Weld connector: **TikTok Ads** ([docs](https://weld.app/docs/applications/tiktok-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_tiktok_ads__ad_performance_daily.sql) | Ads Manager, Ads tab, by day, with video and engagement metrics | day × advertiser × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_tiktok_ads__campaign_performance_daily.sql) | Ads Manager, Campaigns tab, by day, with CTR, CPC, CPM, cost per conversion and Complete payment ROAS | day × advertiser × campaign |
| [`weld/core/ad_group_performance_daily.sql`](weld/core/ad_group_performance_daily.sql) · [dbt](dbt/models/core/core_tiktok_ads__ad_group_performance_daily.sql) | Ads Manager, Ad groups tab, by day, with the optimisation goal that defines each group's conversions | day × advertiser × ad group |

TikTok's hierarchy is advertiser (the ad account) > campaign > ad group > ad. All
three reports are built from the one ad level report, so they add up to each other.

## Cross-channel contract

The first twelve columns of `ad_performance_daily` are `date_day, account_id,
account_name, campaign_id, campaign_name, ad_id, ad_name, spend, impressions,
clicks, conversions, conversion_value`, the same set the other paid ads templates
here emit. Select those twelve from each and `UNION ALL` them for a blended spend
report. The `source` and `currency` columns that follow tell the rows apart; convert
currencies before summing across accounts.

In TikTok terms: `account_id` is the **advertiser ID** and the ad set level is the
**ad group**.

**What `conversions` means.** It is TikTok's "Conversions" column: how often the
ad group's optimisation event happened, under the attribution window set on that
ad group. A purchase-optimised ad group counts purchases, a lead ad group counts
form submits, an app ad group counts installs or in-app events. The ad level and ad
group level reports carry `optimization_goal` and `optimization_event` so you can
tell them apart; filter on them before comparing cost per conversion with another
channel.

**What `conversion_value` means.** It is the value of website Complete Payment
events, the purchase event of the TikTok Pixel and Events API, so `roas` is
TikTok's "Complete payment ROAS". It is a purchase value whatever the ad group
optimises for. In-app purchases are kept apart in `app_purchases` and
`app_purchase_value`.

## Layers

```
raw.tiktok_ads.*          ELT output, untouched
  ↓
weld/staging/*.sql        5 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.tiktok_ads.ad}}` expects the
model in a `staging > tiktok_ads` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_daily_report`, `ad`, `ad_group`, `campaign`, `advertiser` |
| campaign performance daily | the same, through `ad_performance_daily` |
| ad group performance daily | the same, through `ad_performance_daily` |

All five are standard streams of the connector; no custom report is needed.

## Notes

- **The report is keyed on advertiser, ad and day.** `ad_daily_report` has one row
  per `advertiser_id`, `ad_id` and `stat_time_day`. Staging keeps the latest row
  per key, in case a re-sync loaded one twice.
- **Report values arrive as strings.** TikTok's reporting API returns every metric
  as text. The connector converts them to numbers on load, and staging casts again
  with `SAFE_CAST`, so a malformed value becomes 0 instead of failing the run.
  `stat_time_day` stays text (`2024-05-01 00:00:00`) and staging cuts it to a date.
- **Days are the advertiser's days.** TikTok reports in the advertiser's own
  timezone, so dates line up with Ads Manager without conversion.
- **Money is in whole currency units,** in the advertiser's currency. No micros.
- **Complete payment value is rebuilt.** The connector syncs the Complete Payment
  count and the average value per payment, not the total. Staging multiplies the
  two. TikTok rounds the average, so expect differences of a few cents per ad and
  day against Ads Manager.
- **Reach is not summed.** One person can see several ads, so reach is only on the
  ad level report and left out of the ad group and campaign reports.
- **Late conversions.** Conversions are dated on the ad interaction and keep
  arriving after the day ends. The connector re-reads the previous 24 hours on the
  first sync of each day, which catches most, but not all, late conversions. A
  periodic full resync of `ad_daily_report` closes the gap.
- **Deleted ads.** Unless the connector setting to fetch deleted ads for reports
  is on, ads deleted before a day was synced are missing from the report, and
  spend will be lower than Ads Manager's account total.
- **Names and settings are the current ones.** The entity streams keep one version
  per id, so a renamed campaign shows its new name on every past day, and `budget`
  on the ad group report is today's budget.
- **Several advertisers.** Every join includes `account_id`, so syncing several
  advertisers into the same tables works without changes.
- **Not run against a warehouse.** These models were checked for syntax, references
  and column names only. Reconcile a week of spend, impressions, clicks and
  conversions per campaign against Ads Manager before relying on the output.

## Schema notes

The public ERD and the connector's stream definitions agree for every column used
here. The ERD types the report metrics as numbers; they are numbers in the
warehouse because the connector converts TikTok's strings on load.

## Vendor docs

- TikTok API for Business documentation (reporting): <https://business-api.tiktok.com/portal/docs>
- TikTok Ads Manager help, attribution windows for an ad group: <https://ads.tiktok.com/help/article/attribution-settings-at-the-ad-group-level>
- TikTok Ads Manager help, attribution overview: <https://ads.tiktok.com/help/article/attribution-overview>
