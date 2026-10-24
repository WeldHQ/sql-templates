-- Monthly waste per account equals the daily waste summed over the month.
-- Returns zero rows when they agree within a gram per row.

WITH daily AS (
    SELECT DATE_TRUNC(registration_date, MONTH) AS month, account_id, SUM(waste_kg) AS kg, COUNT(*) AS n
    FROM {{ ref('core_esmiley__food_waste_daily') }}
    GROUP BY 1, 2
),
monthly AS (
    SELECT month, account_id, SUM(waste_kg) AS kg
    FROM {{ ref('core_esmiley__food_waste_by_area_month') }}
    GROUP BY 1, 2
)

SELECT d.month, d.account_id, d.kg AS daily_kg, m.kg AS monthly_kg
FROM daily d
LEFT JOIN monthly m USING (month, account_id)
WHERE m.kg IS NULL
   OR ABS(d.kg - m.kg) > 0.001 * d.n
