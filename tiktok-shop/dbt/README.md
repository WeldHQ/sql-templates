# TikTok Shop dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source
models/staging/stg_tiktok_shop__*.sql                   8 thin wrappers over the raw tables
models/core/core_tiktok_shop__sales_over_time.sql       sales equation per day
models/core/core_tiktok_shop__product_sales_over_time.sql  the same by product and SKU
models/core/core_tiktok_shop__settlement_ledger.sql     what TikTok paid out, per transaction
models/core/core_tiktok_shop__shop_performance.sql      TikTok's own daily shop analytics
models/analytics/analytics__tiktok_shop_*.sql           thin BI-facing contracts
tests/assert_tiktok_shop__product_reconciles_to_sales.sql            product level sums to day level
tests/assert_tiktok_shop__settlement_ties_to_statements.sql          transactions sum to each statement payout
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two cannot disagree
about the logic.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands
the TikTok Shop tables.

**Your timezone.** Set `report_timezone` in `stg_tiktok_shop__shop.sql`. It
defaults to `UTC`; Seller Center reports in the shop's local time.

## Notes

- **Plain SQL, no macros.** A second connection is a `UNION ALL` block per staging
  model with a different `tiktok_account` label.
- **Not run end to end.** Reconcile a month against Seller Center before relying
  on the output.
