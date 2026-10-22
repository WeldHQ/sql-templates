-- staging.notion.page
-- Thin wrapper over raw `page`. One row per page, latest version.
--
-- A row in a Notion database is a page whose parent is a data source. Since
-- Notion's 2025 API change a database can hold several data sources; older pages
-- may still only carry the parent database id, which core resolves.

SELECT
    CAST(id AS STRING)                      AS page_id,
    LOWER(CAST(parent_type AS STRING))      AS parent_type,
    CAST(parent_data_source_id AS STRING)   AS parent_data_source_id,
    CAST(parent_database_id AS STRING)      AS parent_database_id,
    CAST(parent_page_id AS STRING)          AS parent_page_id,
    CAST(created_time AS TIMESTAMP)         AS created_at,
    CAST(created_by_id AS STRING)           AS created_by_id,
    CAST(last_edited_time AS TIMESTAMP)     AS last_edited_at,
    CAST(last_edited_by_id AS STRING)       AS last_edited_by_id,
    COALESCE(archived, FALSE) OR COALESCE(in_trash, FALSE) AS is_archived,
    CAST(url AS STRING)                     AS url
FROM {{raw.notion.page}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY CAST(last_edited_time AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
