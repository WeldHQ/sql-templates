# AppLovin templates

Daily campaign and creative set performance for advertisers on AppLovin (AppDiscovery,
now part of Axon), in the same shape as the other paid ads templates in this repo.
BigQuery.

Weld connector: **AppLovin** ([docs](https://weld.app/docs/applications/applovin)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_applovin__ad_performance_daily.sql) | Advertiser report by campaign and creative set, by day | day × campaign × creative set |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_applovin__campaign_performance_daily.sql) | Advertiser report by campaign, by day, with CTR, CPC, CPM, CPI, install rate and day-0 and day-7 ROAS | day × campaign |

These cover the advertiser side. The connector also syncs publisher and MAX
monetization reports (`publisher_report`, `max_report`); no templates for those yet.

## Cross-channel contract

The first twelve columns of `ad_performance_daily` are `date_day, account_id,
account_name, campaign_id, campaign_name, ad_id, ad_name, spend, impressions,
clicks, conversions, conversion_value`, the same set the other paid ads templates
here emit. Select those twelve from each and `UNION ALL` them for a blended spend
report. The `source` and `currency` columns that follow tell the rows apart.

What the columns hold for AppLovin:

- **The creative set is the lowest level.** The report has no stable ad id, so
  `ad_id` is the creative set id and `ad_name` the creative set name.
- **No account columns.** The reports carry no account id; one Weld connection is
  one AppLovin account, so `account_id` and `account_name` are NULL. Fill them with
  a constant if you blend several accounts.
- `campaign_id` is AppLovin's `campaign_id_external`, which survives renames.
- `conversions` are **installs**. `conversion_value` is **day-7 cohort revenue**
  (in-app purchases plus ad revenue from users who installed that day, within
  seven days). It is NULL for the most recent seven days, so blended ROAS from the
  contract columns only covers older days.

## Layers

```
raw.applovin.*            ELT output, untouched
  ↓
weld/staging/*.sql        2 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.applovin.advertiser_report}}`
expects the model in a `staging > applovin` folder. Mirror that structure or adjust
the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `advertiser_report` |
| campaign performance daily | `advertiser_campaign_report` |

The two reports are synced as separate streams.
`assert_creative_set_spend_reconciles_to_campaigns` checks that they agree.

## Notes

- **Days are UTC.** The AppLovin reporting API reports in UTC only. Check the time zone
  in the dashboard before comparing.
- **Currency is assumed to be USD.** The reporting API does not return a
  currency, so the models set `currency` to `USD`. Check a day of spend against
  the dashboard and change it if your account reports in another currency.
- **Delivery and cohort metrics are dated differently.** Spend, impressions,
  clicks, installs and sales are dated on the day they happened. The `_d0` and
  `_d7` revenue columns are install cohorts: revenue from users who installed on
  that day, within 0 or 7 days. ROAS here is cohort revenue over that day's spend,
  the way AppLovin reports it.
- **Day-7 revenue fills in after seven days.** The connector only asks for a
  cohort window once it has fully elapsed, and re-reads the last seven days once a
  day, so `total_revenue_d7` and `roas_d7` are NULL for the most recent week.
  Day-30 columns are only filled for days that were older than 30 days when first
  synced, so they are left out.
- **History is limited to 45 days back** from the first sync, the window the
  AppLovin reporting API allows. Older data cannot be loaded.
- **Rows are split by many dimensions.** Each report row is one combination of
  country, platform, device, placement, ad size, traffic source and more. Core
  sums them back up; staging keeps the full split if you need it.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, impressions and installs per
  campaign against the AppLovin dashboard (in UTC) before relying on the output.

## Schema notes

No mismatches: every column used is in the public ERD and in the connector's
stream definitions. Revenue and ROAS columns with a time span suffix (`_0d`,
`_7d`) are cohort metrics; the ROAS ones arrive as strings and are not used here,
the template recomputes ROAS from revenue and spend.

## Vendor docs

- [AppLovin Reporting API](https://support.applovin.com/en/growth/promoting-your-apps/api/reporting-api/)
