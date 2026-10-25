# Cross-channel paid media templates

Every ad platform in one table: spend, impressions, clicks, conversions and
conversion value per campaign and day, plus a daily overview per platform with
share of spend. Built on the campaign models of the ad platform templates in this
repo. BigQuery.

| Model | Answers | Grain |
|---|---|---|
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_cross_channel_ads__campaign_performance_daily.sql) | What did each campaign spend and return, across every platform? | day × platform × ad account × campaign |
| [`weld/core/channel_performance_daily.sql`](weld/core/channel_performance_daily.sql) · [dbt](dbt/models/core/core_cross_channel_ads__channel_performance_daily.sql) | How is spend split across platforms, and what does each deliver? | day × platform × currency |

## Read this first

- **Keep only the platforms you sync.** `campaign_performance_daily` is a
  `UNION ALL` with one branch per platform. A branch whose platform model does not
  exist in your project fails the whole query, so delete the branches you do not
  need before deploying. Each branch reads that platform's
  `campaign_performance_daily`, so deploy those first (see each platform's folder).
- **Currencies are never converted.** Every row carries its ad account's currency,
  and the channel overview keeps currency in its grain. If your accounts bill in
  different currencies, convert them before adding spend together, for example
  with the daily rates in [`forex-v2/`](../forex-v2/).
- **Conversions mean something different on every platform.** Each platform
  counts its own primary result (table below). Spend, impressions, clicks, CTR,
  CPC and CPM compare cleanly across platforms. Conversions, cost per conversion
  and ROAS compare a platform with itself over time; across platforms they compare
  different events under different attribution windows.

## Platforms included

| Platform | Folder | `clicks` | `conversions` | `conversion_value` |
|---|---|---|---|---|
| Google Ads | [`google-ads/`](../google-ads/) | clicks | conversion actions included in "Conversions", dated on the click | matching conversion value |
| Meta (Facebook and Instagram) | [`facebook-ads/`](../facebook-ads/) | link clicks | purchases (click and view through, the connector's requested windows) | purchase value |
| Microsoft Advertising | [`microsoft-ads/`](../microsoft-ads/) | clicks | goals set to "Include in conversions" | matching revenue |
| LinkedIn Ads | [`linkedin-ads/`](../linkedin-ads/) | clicks | external website conversions, post click and post view (lead form leads are separate) | value LinkedIn attributes |
| TikTok Ads | [`tiktok-ads/`](../tiktok-ads/) | clicks | the ad group's optimisation event | website Complete Payment value |
| Pinterest Ads | [`pinterest-ads/`](../pinterest-ads/) | Pin clicks (paid and earned) | all conversion events | checkout value |
| Snapchat Ads | [`snapchat-ads/`](../snapchat-ads/) | swipe ups | purchases (28 day swipe, 1 day view) | purchase value |
| Reddit Ads | [`reddit-ads/`](../reddit-ads/) | clicks | purchases, click and view through | purchase value |
| Apple Ads | [`apple-ads/`](../apple-ads/) | taps | tap-through installs | none (NULL) |
| Criteo | [`criteo/`](../criteo/) | clicks | post-click sales within 30 days | sales revenue |

Each platform's README has the full definition and the attribution window it uses.

Not included: Amazon Ads and AppLovin. Their templates do not yet carry the shared
campaign columns; add them once they do, in the same shape as the other branches.

## Layers

```
core.<platform>.campaign_performance_daily   one per platform, from that platform's folder
  ↓
weld/core/campaign_performance_daily.sql      the union: one row per platform, account, campaign, day
weld/core/channel_performance_daily.sql       the daily overview per platform and currency
  ↓
weld/analytics/*.sql                          BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions; see
[dbt/README.md](dbt/README.md).

## Notes

- **Why campaigns and not ads.** Performance Max and similar campaign types have no
  ad-level rows on Google and Microsoft, so only the campaign level carries all of
  their spend. For ad-level comparisons, union the `ad_performance_daily` models
  instead; their first twelve columns line up the same way.
- **Platform names.** `source` holds the platform's namespace (`google_ads`,
  `facebook_ads`, ...). Map it to display names in your BI tool or add a CASE here.
- **Rates are ratios of sums.** To report a week or a month, re-sum spend,
  impressions, clicks, conversions and value, then divide again.
- **Late data differs by platform.** Each connector re-reads a different number of
  recent days, so the latest days settle at different speeds. Each platform's README
  says how many.
- **Not run against a warehouse.** These models were checked for syntax and
  references, and the platform models they read were dry-run where a synced schema
  was available. Reconcile a week of spend per platform against each platform's own
  UI before relying on the totals.
