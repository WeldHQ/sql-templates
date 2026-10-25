# Facebook Ads templates

Daily ad, ad set and campaign performance from Meta (Facebook and Instagram) ads,
with purchases and a breakdown of every conversion event, in the same shape as
the other paid ads templates in this repo. BigQuery.

Weld connector: **Facebook Ads** ([docs](https://weld.app/docs/applications/facebook-ads)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/ad_performance_daily.sql`](weld/core/ad_performance_daily.sql) · [dbt](dbt/models/core/core_facebook_ads__ad_performance_daily.sql) | Ads Manager, Ads tab, by day, with purchases and purchase value | day × ad account × ad |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_facebook_ads__campaign_performance_daily.sql) | Ads Manager, Campaigns tab, by day, with CTR, CPC, CPM, cost per purchase and ROAS | day × ad account × campaign |
| [`weld/core/ad_set_performance_daily.sql`](weld/core/ad_set_performance_daily.sql) · [dbt](dbt/models/core/core_facebook_ads__ad_set_performance_daily.sql) | Ads Manager, Ad sets tab, by day, with optimisation goal and attribution setting | day × ad account × ad set |
| [`weld/core/conversions_by_action_type_daily.sql`](weld/core/conversions_by_action_type_daily.sql) · [dbt](dbt/models/core/core_facebook_ads__conversions_by_action_type_daily.sql) | Results columns per conversion event (purchases, leads, add to carts, custom conversions) | day × ad account × ad × action type |

## Cross-channel contract

`ad_performance_daily` and `campaign_performance_daily` both start with
`date_day, account_id, account_name, currency, campaign_id, campaign_name`, then
(ad model only) `ad_set_id, ad_set_name, ad_id, ad_name`, then `spend,
impressions, clicks, conversions, conversion_value, ctr, cpc, cpm,
cost_per_conversion, roas`. The other paid ads templates here emit the same
columns, so select them from each and `UNION ALL`. `account_id` is part of every
join key, so several ad accounts in one schema stay apart. Convert currencies
before summing across accounts.

Two choices to know before blending: `clicks` is **link clicks**, not "Clicks
(all)" (that is `clicks_all`), and `conversions` counts click-through and
view-through purchases together.

## Layers

```
raw.facebook_ads.*        ELT output, untouched
  ↓
weld/staging/*.sql        8 thin wrappers: cast, strip the act_ prefix, de-duplicate
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.facebook_ads.ad}}` expects the model
in a `staging > facebook_ads` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| ad performance daily | `ad_roas_insight`, `ad_roas_insight_actions`, `ad_roas_insight_action_values`, `ad`, `ad_set`, `ad_set_attribution`, `campaign`, `account` |
| campaign performance daily | the same, through `ad_performance_daily` |
| ad set performance daily | the same, through `ad_performance_daily` |
| conversions by action type daily | `ad_roas_insight_actions`, `ad_roas_insight_action_values`, plus `ad_performance_daily` for labels |

`ad_roas_insight` is one of the streams the connector selects by default; its
`_actions` and `_action_values` tables are written alongside it.
`ad_set_attribution` is written with the `ad_set` stream.

## Notes

- **Spend is in the ad account's currency,** as Meta reports it. No micros or
  cents conversion is needed.
- **account_id has no `act_` prefix.** The connector lands the numeric ad account
  ID; staging strips the prefix anyway, so IDs copied from Ads Manager URLs join.
- **How action arrays land.** Meta returns conversions as arrays of
  `{action_type, value}` pairs. The connector writes each array to its own table
  with one row per action type, keyed by the report row (account, campaign, ad
  set, ad, date). `_actions` holds counts, `_action_values` holds money.
- **Purchases are `omni_purchase`,** which is what the Ads Manager "Purchases"
  column shows: one purchase per event, de-duplicated across website, app and
  offline. Where an account reports no `omni_purchase`, the plain `purchase` type
  is used instead. Never both, and never the channel specific types
  (`offsite_conversion.fb_pixel_purchase`, `onsite_web_purchase`, ...), which are
  subsets of the same purchases.
- **Attribution.** Counts and values are Meta's figures under the attribution
  windows the connector requests: 7-day click and 1-day view unless the connection
  is set otherwise. The ad set's own attribution setting, which can differ, is
  in `ad_set_attribution_setting`.
- **Conversions are dated on the conversion day.** This report asks Meta for
  conversions by the day they happened, not the day of the ad impression, which
  is the Ads Manager default. Daily purchase counts will not match Ads Manager
  day by day for that reason; weekly and monthly totals come close. If you need
  impression-day dating, the `ad_insight` and `ad_insight_actions` tables carry
  counts that way, but have no purchase value.
- **Late conversions.** The connector re-reads the last 7 days once a day.
  Purchases attributed later than that are not picked up.
- **Reach is per ad and day.** It counts unique people and cannot be summed;
  the campaign and ad set models leave it out.
- **Names are the current ones.** Entity streams are re-read in full; deleted ads
  fall back to the names on the report row.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of spend, impressions, link clicks and
  purchases per campaign against Ads Manager (same attribution setting, same
  date range) before relying on the output.

## Schema notes

The ERD and the connector's stream definitions agree on every table and column
these models read. The action tables can also carry per-window columns
(`seven_d_click`, `one_d_view`, and others such as `twenty_eight_d_click`), but
only on connections that request attribution windows explicitly, so the models
do not read them. If your tables have them, add them to the two action staging
models and carry them through `conversions_by_action_type_daily` for a
click-only view.

## Vendor docs

- Marketing API, Insights: <https://developers.facebook.com/docs/marketing-api/insights>
- Insights parameters (attribution windows, action report time): <https://developers.facebook.com/docs/marketing-api/reference/adgroup/insights/>
- About attribution settings: <https://www.facebook.com/business/help/458681590974355>
