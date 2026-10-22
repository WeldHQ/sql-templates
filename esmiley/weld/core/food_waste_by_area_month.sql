-- core.esmiley.food_waste_by_area_month
-- Monthly food waste per account and top-level area, with each area's share of
-- the account's waste and the change from the previous month.
-- Grain: month x account x area x currency.
--
-- share_of_account_kg is the area's weight over the account's total weight in the
-- month. kg_change_vs_previous_month compares with the same area's previous
-- calendar month and is NULL when that month had no registrations.

WITH monthly AS (
    SELECT
        DATE_TRUNC(registration_date, MONTH)   AS month,
        account_id,
        ANY_VALUE(account_name)                AS account_name,
        COALESCE(area, 'Unassigned')           AS area,
        currency,
        SUM(registrations)                     AS registrations,
        SUM(waste_kg)                          AS waste_kg,
        SUM(cost)                              AS cost,
        SUM(co2_kg)                            AS co2_kg
    FROM {{core.esmiley.food_waste_daily}}
    GROUP BY 1, 2, 4, 5
)

SELECT
    m.month,
    m.account_id,
    m.account_name,
    m.area,
    m.currency,
    m.registrations,
    ROUND(m.waste_kg, 3)                                                   AS waste_kg,
    ROUND(m.cost, 2)                                                       AS cost,
    ROUND(m.co2_kg, 3)                                                     AS co2_kg,
    SAFE_DIVIDE(m.waste_kg, SUM(m.waste_kg) OVER (PARTITION BY m.month, m.account_id)) AS share_of_account_kg,
    ROUND(m.waste_kg - p.waste_kg, 3)                                      AS kg_change_vs_previous_month
FROM monthly m
LEFT JOIN monthly p
  ON p.account_id = m.account_id
 AND p.area = m.area
 AND p.currency = m.currency
 AND p.month = DATE_SUB(m.month, INTERVAL 1 MONTH)
