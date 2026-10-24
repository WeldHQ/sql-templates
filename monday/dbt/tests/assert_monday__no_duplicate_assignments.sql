-- item_assignments is unique on item x people column x person.
-- Returns zero rows when it holds.

SELECT
    item_id,
    column_id,
    user_id,
    COUNT(*) AS n
FROM {{ ref('core_monday__item_assignments') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
