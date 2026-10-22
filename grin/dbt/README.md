# Grin dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                               one source, one Grin account
models/staging/stg_grin__*.sql                           11 thin wrappers over the raw tables
models/core/core_grin__creator_campaign_performance.sql  campaign x creator, every source joined
models/core/core_grin__campaign_performance.sql          campaign rollup with cost ratios
models/core/core_grin__conversions_by_day.sql            attributed sales per day
models/analytics/analytics__grin_*.sql                   thin BI-facing contracts
tests/assert_no_duplicate_creator_campaigns.sql          no fan-out at campaign x creator
tests/assert_daily_revenue_ties_to_campaigns.sql         daily series sums to campaign totals
tests/assert_one_currency_per_campaign.sql               campaign revenue sums are single-currency
```

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Grin tables.

**Your time zone**, if not UTC: the `'UTC'` literal in
`core_grin__conversions_by_day`.

## Notes

- **Plain SQL, no macros.** Multiple Grin accounts work by `UNION ALL` in the staging
  models with different `grin_account` labels.
- **Not run end to end.** Reconcile one campaign against Grin before relying on the
  output.
