# Pinterest Ads templates

Daily ad and campaign performance from Pinterest Ads, plus a campaign by country
breakdown, in the same shape as the other paid ads templates in this repo. BigQuery.

Weld connector: **Pinterest Ads** ([docs](https://weld.app/docs/applications/pinterest-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_pinterest_ads__ad_performance_daily.sql) | Ads Manager, Ads tab, by day | day × ad account × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_pinterest_ads__campaign_performance_daily.sql) | Ads Manager, Campaigns tab, by day, with CTR, CPC, CPM, cost per conversion and checkout ROAS | day × ad account × campaign |
| [`weld/core/campaign_country_performance_daily.sql`](weld/core/campaign_country_performance_daily.sql) · [dbt](dbt/models/core/core_pinterest_ads__campaign_country_performance_daily.sql) | Ads Manager, campaigns broken down by country | day × ad account × campaign × country |

In Pinterest, an ad account holds campaigns, a campaign holds ad groups and an ad
group holds ads, where an ad is a promoted Pin. The ad model carries the ad group as its grouping level.

## Cross-channel contract

`ad_performance_daily` and `campaign_performance_daily` both carry `date_day,
account_id, account_name, currency, campaign_id, campaign_name, spend, impressions,
clicks, conversions, conversion_value, ctr, cpc, cpm, cost_per_conversion, roas`
with the same names and meanings as the other paid ads templates here, so they can
be stacked with `UNION ALL`. The ad model adds `ad_id`, `ad_name`, `ad_group_id` and
`ad_group_name`. `source` tells the rows apart. Spend is in each ad account's own
currency; convert before summing across accounts.

### What counts as a conversion

Attribution is Pinterest's API default, because the connector requests the reports
without attribution settings: **30 days after a click, 30 days after an engagement,
1 day after a view**, with conversions dated on the day of the ad action, not the
day of the purchase. Pinterest has stopped attributing new conversions to
engagements, so the engagement window only affects older history.

- `conversions` = Pinterest's total conversions: every conversion event type
  (checkout, sign-up, lead, add to cart, page visit, custom) across web, app and
  offline. The ad report does not carry a checkout count.
- `conversion_value` = checkout value, click plus engagement plus view attributed.
  Only checkouts carry a value in this report, so `roas` is Pinterest's checkout
  ROAS.
- `checkout_value_click`, `checkout_value_engagement` and `checkout_value_view` are
  kept separately. A cross-channel report that counts click-through only should
  use `checkout_value_click`, so Pinterest is not credited with view-throughs that
  other channels leave out.

## Layers

```
raw.pinterest_ads.*       ELT output, untouched
  ↓
weld/staging/*.sql        6 thin wrappers: cast, convert micros, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.pinterest_ads.ad}}` expects the
model in a `staging > pinterest_ads` folder. Mirror that structure or adjust the
refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_report`, `ad`, `ad_group`, `campaign`, `ad_account` |
| campaign performance daily | the same, through `ad_performance_daily` |
| campaign country performance daily | `campaign_country_report`, `campaign`, `ad_account` |

## Notes

- **Money is in micros.** Columns named `*_IN_MICRO_DOLLAR` hold millionths of the
  ad account's currency; the "dollar" in the name does not mean USD. Staging
  divides by 1,000,000. Check one day's spend against Ads Manager for an account
  that does not bill in USD before relying on it.
- **Impressions are paid, clicks are total Pin clicks.** The ad report carries paid
  impressions but not paid-only Pin clicks, so `clicks` includes earned (organic)
  Pin clicks on promoted Pins and CTR runs slightly high compared with a paid-only
  figure. Paid outbound clicks are in `paid_outbound_clicks`.
- **Late conversions.** Conversions keep arriving for up to 30 days after the ad
  action. The connector re-reads only from the day before its previous run, so
  conversions added later to older days are picked up by a full refresh of the
  report streams. Spend and delivery settle within a day.
- **Account is part of every join.** The reports carry the ad account, campaign
  and ad group ids themselves; every join to an entity table matches on
  `account_id` and the id. Entity tables are incremental and can hold several
  versions of one object, so staging keeps the most recently synced one.
- **Deleted ads keep their spend.** Entity tables are joined with `LEFT JOIN`; an ad
  missing from `ad` still counts, with a NULL name. The campaign name falls back to
  the name on the report row.
- **Names are the current ones.** A renamed campaign shows its new name on every
  past day.
- **Country rows do not always add up.** Pinterest reports a country only when it
  can resolve one, so a campaign's country rows can sum to less than the campaign
  total. Use the campaign model for totals.
- **History is limited.** Pinterest's analytics API reaches roughly 2.5 years back,
  so the first sync cannot load older data.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, impressions, clicks, conversions and
  checkout value per campaign against Ads Manager (same attribution windows) before
  relying on the output.

## Schema notes

The public ERD and the connector agree on every column these models read. Report
columns land in upper case (`SPEND_IN_MICRO_DOLLAR`, `DATE`), entity columns in
lower case. The ERD lists the report `DATE` column as a date; the connector writes
it as a timestamp at midnight. Staging reads either form.

## Vendor docs

- Pinterest API v5, ad analytics: <https://developers.pinterest.com/docs/api/v5/ads-analytics/>
- Pinterest API v5, async reports: <https://developers.pinterest.com/docs/api/v5/analytics-create_report/>
