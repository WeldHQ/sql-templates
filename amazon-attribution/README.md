# Amazon Attribution templates

What your off-Amazon marketing (search, social, email, influencers) drove on Amazon:
click-throughs, detail page views, add to carts, purchases and sales per campaign,
creative and product, plus the Brand Referral Bonus. BigQuery.

Weld connector: **Amazon Attribution** ([docs](https://weld.app/docs/applications/amazon-attribution)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/creative_performance_daily.sql`](weld/core/creative_performance_daily.sql) · [dbt](dbt/models/core/core_amazon_attribution__creative_performance_daily.sql) | Attribution console, creative level, by day, in the cross-channel ad shape | day × profile × advertiser × campaign × ad group × creative |
| [`weld/core/campaign_performance_daily.sql`](weld/core/campaign_performance_daily.sql) · [dbt](dbt/models/core/core_amazon_attribution__campaign_performance_daily.sql) | Attribution console, campaign level, by day, with funnel rates and Brand Referral Bonus | day × profile × advertiser × campaign |
| [`weld/core/product_performance_daily.sql`](weld/core/product_performance_daily.sql) · [dbt](dbt/models/core/core_amazon_attribution__product_performance_daily.sql) | Products report: promoted, brand halo and new-to-brand results per ASIN | day × profile × advertiser × campaign × ad group × ASIN × conversion type |

## Cross-channel contract

The first twelve columns of `creative_performance_daily` are `date_day, account_id,
account_name, campaign_id, campaign_name, ad_id, ad_name, spend, impressions,
clicks, conversions, conversion_value`, the same set the paid ads templates here
emit. Amazon Attribution only measures what happens after someone clicks through to
Amazon, so the contract is partly empty:

| Column | Here |
|---|---|
| `account_id`, `account_name` | the Attribution advertiser |
| `campaign_name`, `ad_name` | NULL: the reports carry ids only |
| `ad_id` | the Attribution creative (tag); `unknown` when Amazon could not tie a click to one |
| `spend`, `impressions` | NULL: they belong to the platform that served the ad |
| `clicks` | click-throughs to Amazon |
| `conversions`, `conversion_value` | total purchases and sales (promoted products plus brand halo), 14 day window |

Stacking these rows with `UNION ALL` next to Google Ads or Meta rows would count the
same clicks twice. The useful pattern is a join: spend and impressions from the
platform that served the ad, Amazon sales from here, matched on the Attribution tag
you put on that campaign. That mapping is yours to maintain; Amazon does not return
the source campaign's id.

## Layers

```
raw.amazon_attribution.*      ELT output, untouched
  ↓
weld/staging/*.sql            5 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql               the reports, all the business logic lives here
  ↓
weld/analytics/*.sql          BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.amazon_attribution.profile}}`
expects the model in a `staging > amazon_attribution` folder. Mirror that structure
or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| creative performance daily | `performance_report_by_creative`, `advertiser`, `profile` |
| campaign performance daily | `performance_report_by_campaign`, `advertiser`, `profile` |
| product performance daily | `product_report`, `profile` |

`performance_report_by_adgroup` is not used: everything in it is in the creative
report except the Brand Referral Bonus, which the campaign report also has.

## Notes

- **No spend.** Amazon Attribution does not know what you paid Google, Meta or
  TikTok. Return on ad spend needs the spend from that platform's template.
- **Total versus promoted.** Every metric comes twice: for the products on the
  campaign ("promoted") and for those plus every other product of the same brand
  ("total", the difference being brand halo). The cross-channel columns use total;
  the campaign model carries both and the difference as `brand_halo_sales`.
- **Fourteen day window, dated on the click.** A purchase is credited to the day of
  the click-through, up to 14 days later. Recent days keep growing. Amazon restates
  the reports after 1, 7 and 28 days, for late conversions and for returns and
  refunds, and the connector re-reads the last 30 days on every sync. Staging keeps
  the latest version of each row.
- **The advertiser is matched by name.** The reports carry the advertiser name, not
  its id. Core looks the id up in `advertiser` within the same profile; an advertiser
  renamed since the report was generated gets a NULL `account_id` and keeps its
  numbers.
- **Brand Referral Bonus** is the credit Amazon pays brand-registered sellers on
  sales it attributes to their off-Amazon traffic. It is only in the campaign and ad
  group reports, which is why the campaign model reads the campaign report directly
  rather than rolling up creatives. Reconcile it against the bonus Amazon reports
  in Seller Central before treating it as revenue.
- **History.** Amazon keeps 13 months of the performance reports and 90 days of the
  products report. The first sync takes what is there; anything older cannot be
  backfilled later.
- **Currency** is the profile's `currency_code`. Convert before summing across
  profiles in different marketplaces.
- **Kindle columns** (`kenp_pages_read`, `kenp_royalties`) are only filled for
  Kindle Direct Publishing authors.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Reconcile a week of click-throughs, purchases and sales per
  campaign against the Amazon Attribution console before relying on the output.

## Schema notes

The public ERD and the schema Weld syncs agree for every table and column used
here.

## Vendor docs

- [Amazon Attribution API overview](https://advertising.amazon.com/API/docs/en-us/guides/amazon-attribution/overview)
- [Amazon Attribution reporting guide](https://advertising.amazon.com/API/docs/en-us/guides/amazon-attribution/how-to)
