-- labour_vs_sales is unique on date x department. Returns zero rows when it holds.

SELECT date, department_id, COUNT(*) AS n
FROM {{ ref('core_fourth__labour_vs_sales') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
