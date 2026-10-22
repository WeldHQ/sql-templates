# Criteo templates

Daily ad and campaign performance from Criteo, in the same shape as the other paid
ads templates in this repo. BigQuery.

Weld connector: **Criteo** ([docs](https://weld.app/docs/applications/criteo)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_criteo__ad_performance_daily.sql) | Commerce Growth analytics by ad, by day | day × campaign × ad set × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_criteo__campaign_performance_daily.sql) | Commerce Growth analytics by campaign, by day, with CTR, CPC, CPM, CPO, conversion rate and ROAS | day × advertiser × campaign |

## Cross-channel contract

The first twelve columns of `ad_performance_daily` are `date_day, account_id,
account_name, campaign_id, campaign_name, ad_id, ad_name, spend, impressions,
clicks, conversions, conversion_value`, the same set the other paid ads templates
here emit. Select those twelve from each and `UNION ALL` them for a blended spend
report. The `source` and `currency` columns that follow tell the rows apart.

In Criteo terms: `account_id` and `account_name` are the **advertiser**,
`impressions` are **displays**, `spend` is **advertiser cost**, and `conversions`
are **sales**.

## Layers

```
raw.criteo.*              ELT output, untouched
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

Weld references map to folder paths, so `{{staging.criteo.ad}}` expects the model
in a `staging > criteo` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_statistics_daily_report`, `campaign`, `adset`, `ad`, `advertiser` |
| campaign performance daily | the same, through `ad_performance_daily` |

The connector also syncs `campaign_statistics_daily_report` and
`adset_statistics_daily_report`. They carry the same metrics at a coarser grain and
are not needed here: the ad report already includes spend that Criteo cannot tie to
an ad (see below), so it sums to the campaign totals.

## Notes

- **Currency and timezone are connector settings.** The statistics reports are
  requested in the one currency you pick when setting up the connector, for every
  advertiser, and days are cut in the timezone you pick (UTC when left empty). Set
  both to match the Criteo UI before comparing numbers. The `currency` column shows
  what was used.
- **Money is in whole currency units,** not micros or cents. Criteo's statistics
  documentation does not state the unit of `AdvertiserCost` explicitly; check one
  day of spend against the Criteo UI.
- **Conversions are post-click 30-day sales on the same device** (`SalesPc30d`),
  with `RevenueGeneratedPc30d` as the value. Criteo offers several attribution
  models. The core model also carries cross-device (`sales_all_pc_30d`), post-view
  24-hour (`sales_pv_24h`) and client attribution (`sales_client_attribution`)
  sales and revenue. Client attribution is only filled when you send Criteo your
  own attribution data. If your team reports on another model, swap it into
  `conversions` and `conversion_value` in the core model.
- **Unattributed spend sits under ad id `-1`.** Criteo reports spend it cannot
  assign to an ad under a placeholder ad id, once per ad set. Those rows are kept,
  with the name Criteo gives them, so totals match. `active_ads` in the campaign
  model does not count them.
- **The advertiser comes from the campaign.** The statistics report has no
  advertiser column, so the account is looked up through `campaign` (then `adset`,
  then `ad`). If the entity streams are not synced, `account_id` is NULL.
- **Re-synced days are de-duplicated.** If a day is synced more than once, staging
  keeps the latest row per day, campaign, ad set and ad.
- **History goes back two years at most,** the limit the connector requests.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, displays and clicks per campaign
  against the Criteo UI (same currency, same timezone, same attribution) before
  relying on the output.

## Schema notes

No mismatches: every column used is in the public ERD and in the connector's
stream definitions. The report's metric columns are the snake_cased Criteo metric
names, so `SalesPc30d` lands as `sales_pc_30_d` and `AdvertiserCost` as
`advertiser_cost`.

## Vendor docs

- [Criteo API: Campaign statistics](https://developers.criteo.com/marketing-solutions/docs/campaign-statistics)
