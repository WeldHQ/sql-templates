# QRFY dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                                one source, one QRFY account
models/staging/stg_qrfy__analytics.sql                    one row per scan
models/staging/stg_qrfy__qr.sql                           one row per QR code
models/core/core_qrfy__scans_daily.sql                    scans and unique scans per code per day
models/core/core_qrfy__scans_by_location_and_device.sql   country, city and OS per code per month
models/core/core_qrfy__qr_codes.sql                       every code with QRFY's lifetime counter
models/analytics/analytics__qrfy_*.sql                    thin BI-facing contracts
tests/assert_qrfy__breakdown_reconciles_to_daily.sql            breakdown sums to the daily totals
tests/assert_qrfy__unique_scans_within_scans.sql                unique scans never exceed scans
```

Four layers, same as the Weld side: raw, staging, core, analytics. The analytics models
are `SELECT *` by design: dashboards bind to them so core stays free to change.

These are the same models as [`../weld/`](../weld/), differing only in ref syntax. They
are generated from the Weld versions, so the two dialects cannot disagree.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the QRFY
tables. Nothing else to configure.

## Notes

- **Not run end to end.** Nothing here has been run against a warehouse. Compare a few
  codes with QRFY's Statistics page before relying on the output.
