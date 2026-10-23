# Claimlane dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                              one source, one Claimlane connection
models/staging/stg_claimlane__b2c_ticket*.sql           consumer tickets, lines, refunds
models/staging/stg_claimlane__b2b_ticket*.sql           retailer claims and their lines
models/core/core_claimlane__b2c_claim_lines.sql         one row per claimed product
models/core/core_claimlane__b2c_claims_by_month.sql     volume, settlement, refunds per month
models/core/core_claimlane__b2c_claims_by_product.sql   products and reasons
models/core/core_claimlane__b2b_claim_lines.sql         retailer claim lines with decision
models/core/core_claimlane__b2b_claims_by_month.sql     acceptance per brand per month
models/analytics/analytics__claimlane_*.sql             thin BI-facing contracts
tests/assert_claimlane__no_duplicate_b2c_claim_lines.sql           one row per claimed product
tests/assert_claimlane__b2c_monthly_reconciles.sql                 monthly tickets and refunds sum back
tests/assert_claimlane__b2b_statuses_are_classified.sql            unknown statuses hiding in 'other'
```

Four layers, same as the Weld side: raw → staging → core → analytics. The analytics
models are `SELECT *` by design: dashboards bind to them so core stays free to
change.

**These are the same models as [`../weld/`](../weld/), differing only in ref
syntax.** They are generated from the Weld versions, so the two dialects cannot
silently disagree about what a claim was worth.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever your loader lands the
Claimlane tables.

**Only the side you use.** The B2C and B2B models are independent. If you only sync
consumer tickets, drop the `b2b` models and their test.

No vars to set, no packages required: the tests are plain `SELECT`s.

## Notes

- **BigQuery.** `GENERATE_DATE_ARRAY`, `COUNTIF`, `SAFE_DIVIDE`, `ARRAY_AGG ...
  LIMIT` and `IS NOT DISTINCT FROM` in join conditions need swapping for other
  engines.
- **`core_claimlane__b2c_claim_lines` is worth materializing as a table.** Two other
  core models and its own analytics contract read it.
- **Personal data stays in raw.** Staging does not select consumer names, contact
  details or bank details. Keep it that way if you extend the models.
- **Plain SQL, no macros.** Multiple Claimlane connections work by `UNION ALL` in
  the staging models with different `claimlane_account` labels; the label is already
  part of every join key.
- **Not run end to end.** Reconcile a month of tickets against Claimlane before
  relying on the output.
