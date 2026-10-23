# App Store Connect templates

The App Store funnel, usage, stability, sales and reviews for your iOS, iPadOS and
macOS apps, rebuilt from Apple's Analytics Reports and the daily Sales report.
BigQuery.

Weld connector: **App Store Connect** ([docs](https://weld.app/docs/applications/apple-app-store-connect)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/downloads_and_deletions.sql`](weld/core/downloads_and_deletions.sql) · [dbt](dbt/models/core/core_app_store_connect__downloads_and_deletions.sql) | App Analytics, Installations and Deletions: installs by type (first-time download, redownload, update, restore) and deletions | day × app × territory × source type × device |
| [`weld/core/product_page_conversion.sql`](weld/core/product_page_conversion.sql) · [dbt](dbt/models/core/core_app_store_connect__product_page_conversion.sql) | App Analytics, Sources: impressions, page views, Get taps, downloads, conversion | day × app × territory × source type × device |
| [`weld/core/usage_and_stability.sql`](weld/core/usage_and_stability.sql) · [dbt](dbt/models/core/core_app_store_connect__usage_and_stability.sql) | App Analytics, Usage and Crashes: sessions, session length, crashes per 1,000 sessions | day × app × app version × device |
| [`weld/core/sales_and_proceeds.sql`](weld/core/sales_and_proceeds.sql) · [dbt](dbt/models/core/core_app_store_connect__sales_and_proceeds.sql) | Sales and Trends: units, customer sales and estimated proceeds, refunds netted | day × app × product × country × product category × currencies |
| [`weld/core/ratings_and_reviews.sql`](weld/core/ratings_and_reviews.sql) · [dbt](dbt/models/core/core_app_store_connect__ratings_and_reviews.sql) | Ratings and Reviews: written reviews, average stars, replies | day × app × territory (three-letter code) |

## Layers

```
raw.app_store_connect.*   ELT output, untouched
  ↓
weld/staging/*.sql        6 thin wrappers: cast, rename, de-duplicate, fix refund signs
  ↓
weld/core/*.sql           the reports, all the business logic lives here
  ↓
weld/analytics/*.sql      BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.app_store_connect.sessions}}`
expects the model in a `staging > app_store_connect` folder. Mirror that structure
or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| downloads and deletions | `app_installs_deletions` |
| product page conversion | `app_store_engagement`, `app_installs_deletions` |
| usage and stability | `app_sessions`, `app_crashes` |
| sales and proceeds | `sales_report` |
| ratings and reviews | `customer_reviews` |

## Two kinds of numbers

**Analytics Reports** (`app_installs_deletions`, `app_store_engagement`,
`app_sessions`, `app_crashes`) only include people who agreed to share analytics
with developers, and Apple drops any row with fewer than five users. They are good
for mix, trend and rates, and always lower than the true totals. These tables
come from the Detailed variant of each report, which adds source info and campaign but
applies stricter privacy thresholds than the Standard variant, so small slices
(one campaign in one territory on one day) are the most likely to be missing.

**The Sales report** (`sales_report`) counts every transaction. Use
`sales_and_proceeds` for absolute download and revenue numbers, and the analytics
models for where downloads came from and what people did after.

## Notes

- **Refunds.** Apple writes a refund as negative units, negative customer price and
  positive developer proceeds. Staging takes the absolute per-unit amounts and lets
  the sign come from units, so `customer_sales` and `developer_proceeds` net refunds
  out by plain addition. Multiplying the raw columns turns refunds into sales.
- **Currencies are part of the grain** in `sales_and_proceeds`: customer sales are
  in the customer's currency and proceeds in the currency you are paid in. Convert
  before summing across rows. Proceeds here are Apple's daily estimate; the monthly
  Financial Reports are what you are paid on.
- **Conversion uses impressions, not unique impressions.** Apple's own conversion
  rate divides by unique impressions, which cannot be added across rows. The rates
  here divide summed counts, so they roll up correctly but sit below the App Store
  Connect figure. Compare trends rather than the level.
- **Unique devices and unique users are not carried into core.** Apple counts them
  per row of its file; any sum of them is wrong.
- **Reviews are written reviews only.** Apple's API does not return star-only
  ratings, so `avg_rating` will not match the rating on your App Store page.
- **History.** Apple's analytics reports go back to 1 January 2024 at most. Recent
  days are provisional: Apple says reports are complete within three to five days.
- **Installs are not downloads.** The analytics models count install events on
  devices, labelled with the kind of download behind them. App Store Connect's
  download figures come from Apple's separate Downloads report, counted per Apple
  ID and including pre-orders. See Schema notes.
- **Territory codes.** The analytics reports and the Sales report use two-letter
  codes (`US`); customer reviews use three-letter codes (`USA`), kept as
  `territory_alpha3` so the two are not joined by mistake. Map them before
  combining reviews with downloads.
- Metric definitions were cross-checked against Fivetran's open-source
  `dbt_apple_store` package; the SQL here is written independently for Weld's
  schema.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare a week of units and proceeds per app with Sales and
  Trends, and first-time downloads per source with App Analytics, before relying on
  the output.

## Schema notes

- **`customer_reviews` is not in the public ERD** but is synced, with the columns
  used here (`id`, `app_id`, `rating`, `title`, `created_date`, `territory`,
  `response_id`, `response_last_modified_date`, `response_state`).
- **Some rows can appear once instead of several times.** Rows that Apple splits
  only by `app_download_date` or `page_title` (installs, sessions and crashes), or
  only by `page_title` or `campaign` (store engagement), show up as a single row in
  the warehouse. In the Sales report the same holds for two products sharing a
  title, or one product sold at two prices in the same country on the same day. If
  a day's totals come in below App Store Connect, this is the first thing to check.
  Compare a few days per report against App Store Connect before relying on
  totals.
- **Not synced, so not built.** Weld syncs five Analytics Reports and the
  Summary Sales report. It does not sync Apple's App Store Downloads or Pre-Order
  reports, so per-account download counts and pre-orders are not available; the
  install events above are the closest substitute. It does not sync the
  Subscription, Subscription Event or Subscriber reports either, so active
  subscriptions by offer type (free trial, pay as you go, pay up front), and
  subscribe, renew and cancel events, cannot be built. Auto-renewable
  subscription units and proceeds are still in `sales_and_proceeds` under
  `product_category = 'auto_renewable_subscription'`.
- **Crashes have no territory or source.** Apple's crash report is broken down by
  app version, device and OS version only, which is why `usage_and_stability` has
  no territory or source type.
- **`date` and `processing_date`.** The analytics tables carry both. `processing_date` is the date Apple processed the report instance a row
  came from. If the two are equal on every row in your warehouse, `date` is the
  processing date rather than the event date; for daily instances they normally
  coincide, but late events Apple delivers in a later instance then land on the
  later day.

## Vendor docs

- [Analytics Reports: Installations and Deletions](https://developer.apple.com/documentation/analytics-reports/app-installs)
- [Analytics Reports: Discovery and Engagement](https://developer.apple.com/documentation/analytics-reports/app-store-discovery-and-engagement)
- [Analytics Reports: App Sessions](https://developer.apple.com/documentation/analytics-reports/app-sessions)
- [Summary Sales report fields](https://developer.apple.com/help/app-store-connect/reference/reporting/summary-sales-report)
- [Product type identifiers](https://developer.apple.com/help/app-store-connect/reference/reporting/product-type-identifiers)
