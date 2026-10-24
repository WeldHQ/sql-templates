-- core_fourth__department_location
-- Which location each department belongs to. Sales and payroll only carry a
-- department, so this map is what lets them roll up to a site.
-- Grain: department.
--
-- Built from the rota and the budget, the two streams that carry both ids. A
-- department seen under more than one location takes the one it appears with
-- most often. Departments that appear in neither stream are missing here, and
-- their sales and labour land under location NULL.

WITH pairs AS (
    SELECT department_id, location_id, location_name FROM {{ ref('stg_fourth__shift') }}
    UNION ALL
    SELECT department_id, location_id, location_name FROM {{ ref('stg_fourth__budget') }}
)

SELECT
    department_id,
    location_id,
    ANY_VALUE(location_name) AS location_name
FROM pairs
WHERE department_id IS NOT NULL
  AND location_id IS NOT NULL
GROUP BY department_id, location_id
QUALIFY ROW_NUMBER() OVER (PARTITION BY department_id ORDER BY COUNT(*) DESC, location_id) = 1
