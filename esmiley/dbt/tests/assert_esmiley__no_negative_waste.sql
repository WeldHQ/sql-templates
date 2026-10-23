-- Weights and costs are never negative. Returns zero rows when it holds.

SELECT registration_date, account_id, registration_point_id, waste_kg, cost
FROM {{ ref('core_esmiley__food_waste_daily') }}
WHERE waste_kg < 0
   OR cost < 0
