-- stg_monday__item_column_value
-- Thin wrapper over raw `item_column_values`. One row per item x column.
--
-- monday's column value `id` is the column's id on the board ("status",
-- "person", "date4"), not a value id, so it repeats across items. The unique key
-- is item_id + column_id; the QUALIFY keeps one row per pair in case the
-- substream ever lands the same pair twice.
--
-- `value` is the raw JSON monday stores for the column. For a status column it
-- holds the label index, not the label text; the text only appears in the
-- activity log (see core.monday.status_changes).

SELECT
    CAST(item_id AS STRING)                 AS item_id,
    CAST(COALESCE(column_id, id) AS STRING) AS column_id,
    LOWER(CAST(type AS STRING))             AS column_type,
    SAFE.PARSE_JSON(CAST(value AS STRING))  AS value_json
FROM {{ source('monday', 'item_column_values') }}
WHERE item_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(item_id AS STRING), CAST(COALESCE(column_id, id) AS STRING)
    ORDER BY _weld_synced DESC
) = 1
