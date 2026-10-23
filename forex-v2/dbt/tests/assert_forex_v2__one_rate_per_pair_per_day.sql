-- One rate per day per currency pair.
--
-- Every model that converts currency joins on (date, from_currency, to_currency) and
-- expects exactly one row. A duplicate silently doubles every converted amount. The
-- usual cause is several base currency streams unioned into the staging model:
-- read one base only.

SELECT
    date,
    from_currency,
    to_currency,
    COUNT(*) AS row_count
FROM {{ ref('core_forex_v2__daily_rates') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
