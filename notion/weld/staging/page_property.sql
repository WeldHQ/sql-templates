-- staging.notion.page_property
-- Thin wrapper over raw `page_property`. One row per page x property.
--
-- Notion property ids are only unique within one data source (every title
-- property has id "title"), so the key is page_id + property_id. The connector
-- has already flattened each value into typed columns: string_value for title,
-- text, select, status, email, url and unique id; number_value, date_value and
-- boolean_value for their types, including formula results.

SELECT
    CAST(page_id AS STRING)          AS page_id,
    CAST(id AS STRING)               AS property_id,
    CAST(name AS STRING)             AS property_name,
    LOWER(CAST(type AS STRING))      AS property_type,
    CAST(string_value AS STRING)     AS string_value,
    CAST(number_value AS FLOAT64)    AS number_value,
    CAST(date_value AS TIMESTAMP)    AS date_value,
    CAST(boolean_value AS BOOL)      AS boolean_value
FROM {{raw.notion.page_property}}
WHERE page_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(page_id AS STRING), CAST(id AS STRING)
    ORDER BY _weld_synced DESC
) = 1
