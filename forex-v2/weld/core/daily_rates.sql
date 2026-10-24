-- core.forex_v2.daily_rates
-- The conversion table other models join to. Every day, every pair of currencies
-- the connector quotes, gap-filled, including the identity pair (EUR to EUR = 1) so
-- a join never has to special-case amounts already in the target currency.
--
-- Grain: date x from_currency x to_currency.
-- Depends on: core.forex_v2.daily_base_rates
--
-- DIRECTION. amount_in_to_currency = amount_in_from_currency * rate.
--
-- HOW EACH RATE IS MADE. The connector quotes everything against one base (USD by
-- default), so:
--   identity  from = to                         rate = 1
--   direct    from = base                       rate = base rate of `to`
--   inverse   to = base                         rate = 1 / base rate of `from`
--   cross     neither is the base               rate = base rate of `to` / base rate of `from`
-- A cross rate through the base is how Open Exchange Rates computes non-USD bases
-- too, so it matches what the EUR stream itself would give.
--
-- SIZE. With about 170 currencies this is roughly 29,000 pairs per day. Materialise
-- it as a table. If you only ever convert into one or two reporting currencies,
-- restrict `to_currencies` below and the table shrinks by two orders of magnitude.

WITH base AS (
    SELECT date, base_currency, quote_currency, rate, rate_source_date, is_carried_forward
    FROM {{core.forex_v2.daily_base_rates}}
    WHERE rate IS NOT NULL
),

-- Every currency on every day, the base itself included at rate 1.
currencies AS (
    SELECT date, base_currency, quote_currency AS currency, rate, rate_source_date, is_carried_forward
    FROM base
    WHERE quote_currency <> base_currency
    UNION ALL
    SELECT DISTINCT date, base_currency, base_currency, 1.0, date, FALSE
    FROM base
),

-- Restrict here to cut the table down, e.g. WHERE currency IN ('EUR', 'USD').
to_currencies AS (
    SELECT * FROM currencies
)

SELECT
    f.date,
    f.currency                                                   AS from_currency,
    t.currency                                                   AS to_currency,
    CASE WHEN f.currency = t.currency THEN 1.0
         ELSE t.rate / f.rate END                                AS rate,
    CASE
        WHEN f.currency = t.currency        THEN 'identity'
        WHEN f.currency = f.base_currency   THEN 'direct'
        WHEN t.currency = t.base_currency   THEN 'inverse'
        ELSE 'cross'
    END                                                          AS rate_type,
    f.base_currency                                              AS via_base_currency,
    LEAST(f.rate_source_date, t.rate_source_date)                AS rate_source_date,
    f.is_carried_forward OR t.is_carried_forward                 AS is_carried_forward
FROM currencies f
JOIN to_currencies t
  ON t.date = f.date
 AND t.base_currency = f.base_currency
