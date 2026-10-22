# Apple Ads templates

Daily campaign and app performance from Apple Ads (formerly Apple Search Ads), in
the same shape as the other paid ads templates in this repo. BigQuery.

Weld connector: **Apple Ads** ([docs](https://weld.app/docs/applications/apple-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_apple_ads__campaign_performance_daily.sql) | Apple Ads Campaigns view by day, with TTR, average CPT, average CPM, cost per install and install rate | day × organization × campaign |
| [`weld/core/app_performance_daily.sql`](weld/core/app_performance_daily.sql) · [dbt](dbt/models/core/core_apple_ads__app_performance_daily.sql) | Spend and installs per promoted app, all campaigns combined | day × organization × app |

## Cross-channel contract

The first twelve columns of `campaign_performance_daily` are `date_day,
account_id, account_name, campaign_id, campaign_name, ad_id, ad_name, spend,
impressions, clicks, conversions, conversion_value`, the same set the other paid
ads templates here emit. Select those twelve from each and `UNION ALL` them for a
blended spend report. The `source` and `currency` columns that follow tell the rows
apart.

What the columns hold for Apple Ads:

- **Campaign is the lowest level.** The connector syncs performance per campaign
  only, so `ad_id` and `ad_name` are NULL. Ad group and keyword lists are synced,
  but without metrics.
- `account_id` is the Apple Ads **organization** id. The organization name is not
  synced, so `account_name` is NULL; fill it in with a mapping if you need it.
- `clicks` are **taps**. `conversions` are **tap-through installs** (see the notes
  on install columns below).
- Apple Ads reports no revenue, so `conversion_value` is NULL. Join your own
  in-app revenue by app and date if you need ROAS.

## Layers

```
raw.apple_ads.*           ELT output, untouched
  ↓
weld/staging/*.sql        2 thin wrappers: cast, rename, parse budgets, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.apple_ads.campaign}}` expects
the model in a `staging > apple_ads` folder. Mirror that structure or adjust the
refs.

## Required tables

| Model | Raw tables |
|---|---|
| campaign performance daily | `campaign_reports`, `campaigns` |
| app performance daily | the same, through `campaign_performance_daily` |

## Notes

- **Check that the install columns are filled.** The connector stores installs
  under Apple's older field names (`installs`, `new_downloads`, `redownloads`).
  Apple's current reporting API, which the connector calls, returns them as
  `tapInstalls`, `tapNewDownloads` and `tapRedownloads`, so these columns may be
  empty in your warehouse. Run `SELECT COUNT(installs) FROM campaign_reports`
  first. If it is 0, `conversions`, cost per install and install rate will be NULL
  while spend, impressions and taps are still correct. View-through and total
  installs are not synced.
- **Dates follow the organization's reporting time zone,** Apple's default for
  reports, so days line up with the Apple Ads UI.
- **Spend is in the organization's currency,** in whole units, taken from Apple's
  `localSpend`.
- **The report is re-read in full on every sync** (two years back by default), so
  late-arriving installs are picked up. Staging keeps the latest row per campaign
  and day.
- **Campaigns with no delivery on a day have no row** for that day.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, impressions and taps per campaign
  against the Apple Ads UI before relying on the output.

## Schema notes

The public ERD calls the report table `campaign_reports` and its columns match the
connector's stream definition. The mismatch is with Apple's API, not the ERD: the
install and rate columns (`installs`, `new_downloads`, `redownloads`,
`lat_on_installs`, `lat_off_installs`, `avg_cpa`, `conversion_rate`) carry the
pre-v5 names, which Apple's v5 reporting API no longer returns. The rate columns
are not used here; the template recomputes rates from the base counts.

## Vendor docs

- [Apple Ads API: Get campaign-level reports](https://developer.apple.com/documentation/apple_ads/get-campaign-level-reports)
- [Apple Ads API: SpendRow (report metrics)](https://developer.apple.com/documentation/apple_ads/spendrow)
