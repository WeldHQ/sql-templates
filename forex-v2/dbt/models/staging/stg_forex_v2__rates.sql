-- stg_forex_v2__rates
-- Thin wrapper over one base currency stream from the Forex connector. One row per
-- day per quote currency: how many units of the quote currency one unit of the base
-- currency buys on that day.
--
-- Grain: date x base currency x quote currency.
--
-- DIRECTION. exchange_rate is quoted as 1 base = rate x quote. With the USD stream,
-- the EUR row on a given day might read 0.92: one US dollar buys 0.92 euros. To
-- convert an amount from the base currency, multiply; to convert into it, divide.
--
-- WHICH STREAM. The connector offers one stream per base currency (USD_rates,
-- EUR_rates, and so on). One base is enough: every other pair is derived from it in
-- core.forex_v2.daily_base_rates and core.forex_v2.daily_rates. This model reads
-- the USD stream. To use a different base, point the ref at that stream; do not
-- UNION several bases here, or the cross rates downstream will be duplicated.
--
-- TABLE NAME. Each table is named after its base currency in upper case, and the
-- table name and the ref keep that casing, so the ref is
-- {{ source('forex_v2', 'USD_rates') }}. Change the schema part if your connection is named
-- differently.
--
-- DATES. Rates are daily (end of day, UTC) from Open Exchange Rates. Each day
-- is stored at midnight UTC in `timestamp`, so DATE() in UTC is the rate's
-- day. Today's row is a provisional intraday rate and is replaced by the closing
-- rate on the next sync.
--
-- DE-DUPLICATION. The table has one row per timestamp and quote currency, so a day
-- is normally present once. The QUALIFY keeps the latest synced value in
-- case a day was loaded twice.

SELECT
    DATE(CAST(`timestamp` AS TIMESTAMP))                       AS rate_date,
    UPPER(TRIM(CAST(source_currency AS STRING)))               AS base_currency,
    UPPER(TRIM(CAST(target_currency AS STRING)))               AS quote_currency,
    CAST(exchange_rate AS FLOAT64)                             AS rate
FROM {{ source('forex_v2', 'USD_rates') }}
WHERE exchange_rate IS NOT NULL
  AND exchange_rate > 0
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY DATE(CAST(`timestamp` AS TIMESTAMP)), source_currency, target_currency
    ORDER BY _weld_synced DESC
) = 1
