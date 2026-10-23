-- Every quote currency has a rate on every day from its first rate to today.
--
-- This is the point of the gap fill: a join on any calendar day must find a rate,
-- weekends and missed syncs included. A pair with fewer rows than days in its range,
-- or with a NULL rate, means the date spine or the carry-forward broke.

SELECT
    base_currency,
    quote_currency,
    MIN(date)                                       AS first_date,
    MAX(date)                                       AS last_date,
    COUNT(*)                                        AS days_present,
    DATE_DIFF(MAX(date), MIN(date), DAY) + 1        AS days_expected,
    COUNTIF(rate IS NULL)                           AS null_rates
FROM {{ ref('core_forex_v2__daily_base_rates') }}
GROUP BY 1, 2
HAVING COUNT(*) <> DATE_DIFF(MAX(date), MIN(date), DAY) + 1
    OR COUNTIF(rate IS NULL) > 0
