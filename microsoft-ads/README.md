# Microsoft Ads templates

Daily account, campaign, ad group and ad performance from Microsoft Advertising
(formerly Bing Ads), in the same shape as the other paid ads templates in this
repo. BigQuery.

Weld connector: **Microsoft Ads** ([docs](https://weld.app/docs/applications/bing-microsoft-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_microsoft_ads__ad_performance_daily.sql) | Ad performance report, by day | day × account × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_microsoft_ads__campaign_performance_daily.sql) | Campaign performance report, by day, with CTR, CPC, CPM, cost per conversion and ROAS | day × account × campaign |
| [`weld/core/ad_group_performance_daily.sql`](weld/core/ad_group_performance_daily.sql) · [dbt](dbt/models/core/core_microsoft_ads__ad_group_performance_daily.sql) | Ad group performance report, by day | day × account × ad group |
| [`weld/core/account_performance_daily.sql`](weld/core/account_performance_daily.sql) · [dbt](dbt/models/core/core_microsoft_ads__account_performance_daily.sql) | Account performance report, by day, with the account's time zone | day × account |

## Cross-channel contract

`ad_performance_daily` and `campaign_performance_daily` both start with
`date_day, account_id, account_name, currency, campaign_id, campaign_name`, then
(ad model only) `ad_group_id, ad_group_name, ad_id, ad_name`, then `spend,
impressions, clicks, conversions, conversion_value, ctr, cpc, cpm,
cost_per_conversion, roas`. The other paid ads templates here emit the same
columns, so select them from each and `UNION ALL`. `account_id` is part of every
join key, so several accounts in one schema stay apart. Convert currencies before
summing across accounts.

For a cross-channel spend total, stack the campaign models, not the ad models:
the ad report does not cover Performance Max (see Notes).

## Layers

```
raw.microsoft_ads.*       ELT output, untouched
  ↓
weld/staging/*.sql        7 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.microsoft_ads.ad}}` expects the model
in a `staging > microsoft_ads` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_performance_daily_report`, `ad`, `ad_group`, `campaign`, `account` |
| campaign performance daily | `campaign_performance_daily_report`, `campaign`, `account` |
| ad group performance daily | `ad_group_performance_daily_report`, `ad_group`, `campaign`, `account` |
| account performance daily | the same as campaign performance daily, through that model |

## Notes

- **Money is in the account's currency,** not micros. Each report row carries its
  `currency_code`; an account has one currency, so it is taken per account.
- **conversions vs all conversions.** `conversions` counts conversion goals set to
  "Include in conversions"; `conversion_value` is their revenue. `all_conversions`
  and `all_revenue` count every goal, as in the "All conv." columns of the UI.
  Pick one pair for ROAS and stick with it. View-through conversions are carried on
  their own as well.
- **Conversions are dated on the day of the ad click,** under each goal's own
  conversion window (30 days by default). A conversion that happens a week after
  the click lands on the click's day.
- **Late conversions.** The connector re-reads the last 3 days of each report once
  a day. Conversions credited to a click older than that are not picked up, so
  recent weeks can read low against the UI. Re-sync the reports from an earlier
  start date to catch up.
- **Ad level is not account level.** Performance Max asset groups have no ad or
  ad group rows, so the ad and ad group models sum to less than the campaign
  model in accounts that run them. The campaign and account models read the
  campaign report for that reason.
- **Report splits are collapsed.** Microsoft's reports split each row by device,
  network, match type, ad distribution and placement; core sums over them.
- **Dates are in the account's time zone,** as Microsoft reports them
  (`account_performance_daily.time_zone`).
- **Names are the current ones.** Entity streams are re-read in full, so a renamed
  campaign shows its new name on every past day. Deleted entities show NULL names.
  Microsoft ads have no name; `ad_name` is the ad title, which responsive search
  ads leave empty.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, clicks and conversions per campaign
  against the Microsoft Advertising UI (same time zone, same columns) before
  relying on the output.

## Schema notes

The ERD and the connector's stream definitions agree on every table and column
these models read. Entity names follow Microsoft's bulk file layout: the campaign
name is in `campaign.campaign`, the ad group name in `ad_group.ad_group`, and
`parent_id` points one level up (ad to ad group, ad group to campaign).

## Vendor docs

- Report columns (Microsoft Advertising API): <https://learn.microsoft.com/en-us/advertising/reporting-service/reporting-service-reference>
- Ad performance report: <https://learn.microsoft.com/en-us/advertising/reporting-service/adperformancereportrequest>
- Campaign performance report: <https://learn.microsoft.com/en-us/advertising/reporting-service/campaignperformancereportrequest>
- Conversions reported on the day of the click: <https://help.ads.microsoft.com/apex/index/3/en/56841>
