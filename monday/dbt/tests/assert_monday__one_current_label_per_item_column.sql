-- Each item and status column has exactly one current label.
-- Returns zero rows when it holds. A failure means the activity log has two
-- changes with the same timestamp and id, which points at duplicated raw rows.

SELECT
    item_id,
    column_id,
    COUNT(*) AS current_rows
FROM {{ ref('core_monday__status_changes') }}
WHERE is_current_label
GROUP BY 1, 2
HAVING COUNT(*) > 1
