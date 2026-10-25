-- Account spend must equal the sum of its campaigns' spend, day by day.
-- Returns zero rows when they agree; a cent of tolerance absorbs rounding.

WITH campaigns AS (
    SELECT date_day, account_id, SUM(spend) AS spend
    FROM {{ ref('core_microsoft_ads__campaign_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(a.date_day, c.date_day)     AS date_day,
    COALESCE(a.account_id, c.account_id) AS account_id,
    a.spend AS account_spend,
    c.spend AS campaign_spend
FROM {{ ref('core_microsoft_ads__account_performance_daily') }} a
FULL OUTER JOIN campaigns c
  ON c.date_day = a.date_day AND c.account_id = a.account_id
WHERE ABS(COALESCE(a.spend, 0) - COALESCE(c.spend, 0)) > 0.01
   OR a.spend < 0
