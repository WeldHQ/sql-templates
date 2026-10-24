-- core.notion.status_breakdown
-- How many pages sit in each status of each database, and how stale they are.
-- The board view of a Notion database, as a table. A snapshot as of the last sync.
-- Grain: data source x status property x status value.
--
-- Archived and trashed pages are excluded. Pages with an empty status show as
-- status NULL. Staleness uses last_edited_at, which moves on any edit to the page,
-- not only status changes: Notion does not expose when a status was set.

SELECT
    data_source_id,
    data_source_title,
    status_property,
    status,
    COUNT(*)                                                    AS pages,
    COUNTIF(days_since_last_edit > 30)                          AS pages_not_edited_30d,
    MIN(created_at)                                             AS oldest_created_at,
    MAX(last_edited_at)                                         AS latest_edit_at,
    APPROX_QUANTILES(days_since_last_edit, 2)[OFFSET(1)]        AS median_days_since_last_edit
FROM {{core.notion.database_pages}}
WHERE NOT is_archived
  AND status_property IS NOT NULL
GROUP BY 1, 2, 3, 4
