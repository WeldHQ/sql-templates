-- staging.notion.data_source
-- Thin wrapper over raw `data_source`. One row per data source (the table inside
-- a Notion database). The title arrives as a JSON array of rich-text runs; it is
-- parsed here and joined into plain text in core.

SELECT
    CAST(id AS STRING)                  AS data_source_id,
    CAST(parent_database_id AS STRING)  AS database_id,
    SAFE.PARSE_JSON(CAST(title AS STRING)) AS title_json,
    COALESCE(archived, FALSE) OR COALESCE(in_trash, FALSE) AS is_archived,
    CAST(created_time AS TIMESTAMP)     AS created_at,
    CAST(url AS STRING)                 AS url
FROM {{raw.notion.data_source}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY _weld_synced DESC) = 1
