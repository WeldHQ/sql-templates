# QRFY templates

Rebuilds QRFY's scan statistics in your warehouse: scans and unique scans per code per
day, where and on what devices codes are scanned, and every code with its lifetime
counter. BigQuery.

Weld connector: **QRFY** ([docs](https://weld.app/docs/applications/qrfy)).

| Model | Recreates | Grain |
|---|---|---|
| [`weld/core/scans_daily.sql`](weld/core/scans_daily.sql) · [dbt](dbt/models/core/core_qrfy__scans_daily.sql) | Statistics: scans over time | day × QR code |
| [`weld/core/scans_by_location_and_device.sql`](weld/core/scans_by_location_and_device.sql) · [dbt](dbt/models/core/core_qrfy__scans_by_location_and_device.sql) | Statistics: countries, cities, operating systems | month × QR code × country × city × OS |
| [`weld/core/qr_codes.sql`](weld/core/qr_codes.sql) · [dbt](dbt/models/core/core_qrfy__qr_codes.sql) | My QR Codes list with scan counts | QR code (now) |

## Layers

```
raw.qrfy.*              ELT output, untouched
  ↓
weld/staging/*.sql      2 thin wrappers: cast, rename, de-duplicate
  ↓
weld/core/*.sql         the reports
  ↓
weld/analytics/*.sql    BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

With [GitHub Sync](https://weld.app/docs/transformations/github-sync) Weld references map
to folder paths, so `{{staging.qrfy.analytics}}` expects the model in a `staging > qrfy`
folder. Mirror that structure in your synced repo, or adjust the refs.

## Required tables

| Model | Raw tables |
|---|---|
| scans daily, scans by location and device | `analytics` |
| qr codes | `qr` |

## Schema notes

- **Scan rows carry no QR id.** QRFY's detailed report identifies a code by its short
  link (`scan_url`) and repeats its name and folder on each scan. The scan models key on
  `scan_url`; the code list keys on the QR id. There is no reliable join between the two,
  so they are kept apart, and `qr_codes.lifetime_scans` is the figure to reconcile the
  scan totals against.
- **How scans are keyed.** The connector keys scan rows on link, scan time, country,
  city, operating system and OS version. Two scans identical on all of those are stored
  once, so summed scans can sit slightly below QRFY's counter.
- **History starts two years back.** Unless you set a start date on the connection, the
  first sync fetches the last two years of scans.
- **Unique scans are per code.** QRFY flags a scan as unique the first time a visitor
  scans that code, so unique scans summed across codes count a person once per code.
- **Location is IP-based.** Country is reliable; city is approximate and can be empty.
- **Days are UTC.**
- **The `qr_data_*` and `qr_style` tables are not used.** They describe each code's
  landing page content and design, which no scan report needs.
- Staging columns were checked against the published ERD and the connector's stream
  definitions; they agree for every table used here.

## Reconciling

Nothing here has been run against a warehouse. Before relying on it, pick three codes and
compare `scans_daily` summed over a closed month with QRFY's Statistics page for the same
codes and dates, and the all-time sum with `qr_codes.lifetime_scans`.

[QRFY API documentation](https://qrfy.com/docs) ·
[Analysis report endpoint](https://qrfy.com/docs/QR/analysis-report)
