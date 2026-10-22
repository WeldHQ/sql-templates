-- core_forex_v2__daily_base_rates
-- Gap-filled daily rates against the base currency: every calendar day from a
-- currency's first rate up to today, with the last known rate carried forward
-- over any day that has none (a missed sync, a currency that stopped quoting, or
-- today when the sync has not run yet).
--
-- Grain: date x base currency x quote currency.
-- Depends on: staging.forex_v2.rates
--
-- Direction as in staging: 1 base = rate x quote. Use core.forex_v2.daily_rates for
-- any other pair; this model is its input and is handy on its own for a quick
-- lookup against the base.
--
-- is_carried_forward is TRUE on a filled day, and rate_source_date says which day's
-- rate was used, so a stale rate is visible rather than silent.

WITH src AS (
    SELECT rate_date, base_currency, quote_currency, rate
    FROM {{ ref('stg_forex_v2__rates') }}
),

pairs AS (
    SELECT
        base_currency,
        quote_currency,
        MIN(rate_date) AS first_date
    FROM src
    GROUP BY 1, 2
),

-- Extend to today even if the latest sync is behind, so a join on today's date
-- still finds a rate. The flag below marks those days.
spine AS (
    SELECT
        p.base_currency,
        p.quote_currency,
        d AS date
    FROM pairs p
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(p.first_date, GREATEST(CURRENT_DATE(), p.first_date))) AS d
)

SELECT
    s.date,
    s.base_currency,
    s.quote_currency,
    LAST_VALUE(r.rate IGNORE NULLS) OVER w                       AS rate,
    LAST_VALUE(r.rate_date IGNORE NULLS) OVER w                  AS rate_source_date,
    r.rate IS NULL                                               AS is_carried_forward
FROM spine s
LEFT JOIN src r
       ON r.base_currency = s.base_currency
      AND r.quote_currency = s.quote_currency
      AND r.rate_date = s.date
WINDOW w AS (
    PARTITION BY s.base_currency, s.quote_currency
    ORDER BY s.date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
