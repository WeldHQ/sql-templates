# Google Play templates

Installs, store listing conversion, stability, subscriptions and earnings for your Android apps,
from the reports Play Console exports to Cloud Storage. BigQuery.

Weld connector: **Google Play** ([docs](https://weld.app/docs/applications/google-play)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/installs_daily.sql`](weld/core/installs_daily.sql) · [dbt](dbt/models/core/core_google_play__installs_daily.sql) | Statistics: user and device installs, uninstalls, active device installs | day × app × country |
| [`weld/core/store_listing_conversion.sql`](weld/core/store_listing_conversion.sql) · [dbt](dbt/models/core/core_google_play__store_listing_conversion.sql) | Store performance: visitors, acquisitions, conversion rate by traffic source | day × app × traffic source |
| [`weld/core/stability_by_app_version.sql`](weld/core/stability_by_app_version.sql) · [dbt](dbt/models/core/core_google_play__stability_by_app_version.sql) | Crashes and ANRs per app version, against its active install base | day × app × version code |
| [`weld/core/subscriptions_daily.sql`](weld/core/subscriptions_daily.sql) · [dbt](dbt/models/core/core_google_play__subscriptions_daily.sql) | Subscriptions: new, canceled and active subscriptions per product | day × app × product × country |
| [`weld/core/earnings_monthly.sql`](weld/core/earnings_monthly.sql) · [dbt](dbt/models/core/core_google_play__earnings_monthly.sql) | Earnings report: charges, Google fees, refunds, taxes, net | month × app × product × payout currency |

## Layers

```
raw.google_play.*       ELT output, untouched
  ↓
weld/staging/*.sql      6 thin wrappers: cast, rename, parse dates, keep the latest file read
  ↓
weld/core/*.sql         the reports, all the business logic lives here
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

Analytics models are `SELECT *` on purpose: dashboards bind to them, so core can be
changed without breaking anything downstream. `dbt/` holds the same models with dbt
refs, generated from the Weld versions; see [dbt/README.md](dbt/README.md).

Weld references map to folder paths, so `{{staging.google_play.earnings}}` expects the
model in a `staging > google_play` folder. Mirror that structure or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| installs daily | `stats_installs_country` |
| store listing conversion | `stats_store_performance_traffic_source` |
| stability by app version | `stats_crashes_app_version`, `stats_installs_app_version` |
| subscriptions daily | `financial_stats_subscriptions_country` |
| earnings monthly | `earnings` |

Play Console exports the same statistics split six ways (by country, device, app
version, OS version, carrier, language), and the connector syncs each split as its
own table. Each split is complete on its own: use one per question and never union
two, or every install is counted twice.

## Notes

- **Users or devices, pick one.** `daily_user_installs` counts Google accounts,
  `daily_device_installs` counts devices. Play Console's acquisition numbers are the
  user ones.
- **Levels are not flows.** `installs_on_active_devices` is how many active devices
  have the app on a given day. Sum the `daily_` columns over a period; for the level,
  take the last day.
- **Recent days change.** Google rewrites the current month's statistics files every
  day. Staging keeps the newest read of each row (by `file_last_modified`), so the
  current month settles as Google finalises it.
- **Conversion is recomputed.** Google puts a conversion rate on every store
  performance row. A rate cannot be summed, so `store_listing_conversion`
  recomputes it from summed acquisitions and visitors, which keeps it correct at any
  rollup.
- **Earnings are signed by Google** and summed as delivered, so `net_earnings`
  should equal the payout for the month in that currency. `other_amounts` collects
  rebills, adjustments and any new transaction type; it should be small. Earnings
  are dated in Pacific Time and Google files them by issue date, so a line can sit
  in the next month's file. A `transaction_date` Google writes in an unexpected
  format parses to NULL rather than failing; check for NULL `month_start` rows.
- **Crash numbers are not Android vitals.** The export carries daily crash and ANR
  counts. Android vitals' crash rate and user-perceived ANR rate are computed per
  daily active user and are not exported; `crashes_per_1000_active_installs` is a
  way to compare versions, not a replacement.
- **Earnings files cover every app in the developer account.** Filter on
  `package_name` if you only report on some.
- **Earnings, not estimated sales.** Play Console's revenue chart comes from the
  estimated sales report, in buyer currencies and before withholding tax and
  chargebacks, so `earnings_monthly` will not match it. Reconcile it to the payout.
  `charged_orders` and `refunded_orders` count distinct order IDs; each
  subscription renewal is its own order.
- **Active subscriptions are a level.** In `subscriptions_daily`, take the last day
  of a period for `active_subscriptions` and sum `new_subscriptions` and
  `canceled_subscriptions`.
- Metric definitions were cross-checked against Fivetran's open-source
  `dbt_google_play` package; the SQL here is written independently for Weld's
  schema.
- **Not run against a warehouse.** These models were checked for syntax and
  references only. Compare a closed month of `net_earnings` with the Play Console
  payout, and a week of user installs with the Statistics page, before relying on
  the output.

## Schema notes

There is no public ERD for this connector; tables and columns follow the connector's
own definitions, which mirror Google's export files.

- **Rows with a blank breakdown share a key.** The statistics tables are keyed on
  date, app and the breakdown column (country, app version, and so on). Google can
  write several rows for the same day with that column empty, for users it cannot
  attribute; they arrive with the same key and only one is kept. Country or version
  totals can therefore come in slightly below the app's overall total in Play
  Console.
- **Ratings are not modelled.** The `stats_ratings_*` tables carry a daily average
  and a running average per breakdown, but no count of ratings, so they cannot be
  added up across countries or days without being wrong. Per-review star ratings
  are in the `reviews` table if you need a rollup you control.

## Vendor docs

- [Download and export monthly reports](https://support.google.com/googleplay/android-developer/answer/6135870)
