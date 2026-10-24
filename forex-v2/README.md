# Forex templates

A daily exchange rate table that any other model can join to convert amounts: every
calendar day, every currency pair, gaps filled with the last known rate. BigQuery.

Weld connector: **Forex** (rates from [Open Exchange Rates](https://openexchangerates.org)).

| Model | What it is | Grain |
|---|---|---|
| [`weld/core/daily_rates.sql`](weld/core/daily_rates.sql) · [dbt](dbt/models/core/core_forex_v2__daily_rates.sql) | The conversion table: direct, inverse and cross rates, plus identity | date × from currency × to currency |
| [`weld/core/daily_base_rates.sql`](weld/core/daily_base_rates.sql) · [dbt](dbt/models/core/core_forex_v2__daily_base_rates.sql) | Gap-filled rates against the base currency | date × base currency × quote currency |

## What the connector provides

One stream per base currency, named after it (`USD_rates`, `EUR_rates`, ...). Each
row is one day and one quote currency:

| Column | Meaning |
|---|---|
| `timestamp` | the rate's day, stored as midnight UTC |
| `source_currency` | the base currency of the stream |
| `target_currency` | the quote currency |
| `exchange_rate` | units of `target_currency` that one unit of `source_currency` buys |

So in `USD_rates`, the EUR row reading `0.92` means 1 USD = 0.92 EUR. Rates are
Open Exchange Rates' daily end of day rates in UTC, back to 1 January 2021 by
default. The current day is a provisional rate and is replaced by the closing rate
on the next sync.

**You only need one base.** Every pair can be derived from one base currency, so
these templates read the USD stream and compute the rest. Do not union several base
streams into staging; the cross rates would be duplicated, and
[`tests/assert_forex_v2__one_rate_per_pair_per_day.sql`](dbt/tests/assert_forex_v2__one_rate_per_pair_per_day.sql)
will fail.

## How the rates are made

`rate` always reads: `amount in to_currency = amount in from_currency * rate`.

| `rate_type` | When | Rate |
|---|---|---|
| `identity` | from = to | 1 |
| `direct` | from is the base | the base rate of `to` |
| `inverse` | to is the base | 1 / the base rate of `from` |
| `cross` | neither is the base | base rate of `to` / base rate of `from` |

**Gap filling.** `daily_base_rates` builds a calendar from each currency's first
rate to today and carries the last known rate forward over any day without one: a
missed sync, a currency that stopped quoting, or today before the sync has run.
`is_carried_forward` marks those days and `rate_source_date` says which day's rate
was used. Open Exchange Rates publishes rates for weekends and holidays itself, so
in practice the fill only covers sync gaps and the current day.

## Joining it

Join on the transaction's date, its currency, and the currency you report in. Use a
`LEFT JOIN`, so a currency the connector does not quote shows up as a NULL amount
rather than a missing row.

```sql
SELECT
    o.order_id,
    o.order_date,
    o.currency,
    o.amount,
    o.amount * fx.rate          AS amount_eur,
    fx.is_carried_forward       AS fx_rate_is_carried_forward
FROM {{staging.shop.orders}} o
LEFT JOIN {{core.forex_v2.daily_rates}} fx
       ON fx.date          = o.order_date
      AND fx.from_currency = o.currency
      AND fx.to_currency   = 'EUR'
```

The identity rows mean orders already in EUR get `rate = 1` and need no special
case. Join on a DATE: if your source has a timestamp, decide which day it belongs to
first (`DATE(created_at)` is the UTC day, `DATE(created_at, 'Europe/Copenhagen')` the
local one). Rates are UTC end of day.

To convert another template's output, the [Adyen](../adyen/) fee model for example,
join on `date`, `net_currency` and your reporting currency in the same way, and sum
the converted amounts only after the join.

## Layers

```
raw.forex_v2.*         ELT output, untouched
  ↓
weld/staging/rates.sql cast, rename, de-duplicate
  ↓
weld/core/*.sql        gap fill and cross rates
  ↓
weld/analytics/*.sql   BI-facing contracts, deliberately thin
```

`dbt/` holds the same models with dbt refs, generated from the Weld versions. See
[dbt/README.md](dbt/README.md).

## Required tables

| Model | Raw tables |
|---|---|
| daily base rates | `USD_rates` (or any one base currency stream) |
| daily rates | the same |

## Size

About 170 currencies give about 29,000 pairs per day, so a few years of history
runs to tens of millions of narrow rows. Materialise `daily_rates` as a table. If
you only convert into one or two reporting currencies, restrict the
`to_currencies` CTE in [`weld/core/daily_rates.sql`](weld/core/daily_rates.sql) and
the table shrinks accordingly.

## Notes

- **Nothing here has been run against a warehouse.** Check a few days against the
  rates Open Exchange Rates shows for those dates, and against the rate your bank or
  payment provider actually used, before relying on converted figures. A reference
  rate is not the rate a transaction settled at: for settled amounts, prefer the
  rate the provider reports, where it exists.
- **Rates are floating point.** Round converted amounts at the end, not in between.

## Schema notes

- **Table names are upper case.** Each table is named after its base currency
  as Open Exchange Rates writes it, so the table is `USD_rates` and the ref
  is `{{raw.forex_v2.USD_rates}}`. BigQuery table names are case sensitive, so keep
  the casing if you copy the ref.
- **`timestamp` type varies.** Most warehouses show it as TIMESTAMP. A few show
  it as an INT64 (epoch
  milliseconds). If yours is INT64, replace `CAST(timestamp AS TIMESTAMP)` with
  `TIMESTAMP_MILLIS(timestamp)` in staging.
