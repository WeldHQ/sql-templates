# Forex dbt models

Drop-in model files. Not a runnable project: no `dbt_project.yml`, not run in CI.

```
models/staging/sources.yml                        one source, one base currency stream
models/staging/stg_forex_v2__rates.sql            daily rates against the base, de-duplicated
models/core/core_forex_v2__daily_base_rates.sql   gap-filled to today, last rate carried forward
models/core/core_forex_v2__daily_rates.sql        every pair: identity, direct, inverse, cross
models/analytics/analytics__forex_v2_*.sql        thin BI-facing contracts
tests/assert_forex_v2__one_rate_per_pair_per_day.sql        a join on (date, from, to) finds one row
tests/assert_forex_v2__no_gaps_in_base_rates.sql            every calendar day has a rate
```

Generated from [`../weld/`](../weld/); the two differ only in ref syntax.

## You supply

**Your schema.** Change `schema:` in `sources.yml` to wherever the Forex tables land.

**The table name.** The connector's table is `USD_rates`, in upper case, and
`sources.yml` uses that name.

## Notes

- Join with `{{ ref('core_forex_v2__daily_rates') }}` on date, `from_currency` and
  `to_currency`; the main [README](../README.md#joining-it) has the full example.
- Materialise `core_forex_v2__daily_rates` as a table. It holds every pair for
  every day.
- **Not run end to end.** Spot check a few days against Open Exchange Rates.
