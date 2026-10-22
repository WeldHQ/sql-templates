-- core.notion.database_pages
-- Every page that is a row in a Notion database, with its title, its status, who
-- created it and how long since anyone touched it.
-- Grain: page.
--
-- Pages are matched to a data source on parent_data_source_id. Pages that only
-- carry a parent database id are matched to that database's data source when the
-- database has exactly one; otherwise data_source_id stays NULL rather than
-- guessing.
--
-- `status` is the value of the page's status-type property. A data source with
-- more than one status property gets the one whose name sorts first; add a filter
-- on property_name in staging.notion.page_property if you need another. Every
-- other property stays in that staging model, one row per page x property.

WITH data_sources AS (
    SELECT
        ds.data_source_id,
        ds.database_id,
        ARRAY_TO_STRING(
            ARRAY(SELECT JSON_VALUE(r, '$.plain_text') FROM UNNEST(JSON_QUERY_ARRAY(ds.title_json)) AS r),
            ''
        ) AS data_source_title
    FROM {{staging.notion.data_source}} ds
),

single_source_databases AS (
    SELECT database_id, ANY_VALUE(data_source_id) AS data_source_id
    FROM data_sources
    GROUP BY 1
    HAVING COUNT(*) = 1
),

titles AS (
    SELECT page_id, string_value AS title
    FROM {{staging.notion.page_property}}
    WHERE property_type = 'title'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY page_id ORDER BY property_name) = 1
),

statuses AS (
    SELECT page_id, property_name AS status_property, string_value AS status
    FROM {{staging.notion.page_property}}
    WHERE property_type = 'status'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY page_id ORDER BY property_name) = 1
)

SELECT
    p.page_id,
    COALESCE(p.parent_data_source_id, s.data_source_id)       AS data_source_id,
    ds.data_source_title,
    t.title,
    st.status_property,
    st.status,
    p.created_at,
    p.created_by_id,
    cu.user_name                                              AS created_by_name,
    p.last_edited_at,
    p.last_edited_by_id,
    eu.user_name                                              AS last_edited_by_name,
    DATE_DIFF(CURRENT_DATE(), DATE(p.last_edited_at), DAY)    AS days_since_last_edit,
    p.is_archived,
    p.url
FROM {{staging.notion.page}} p
LEFT JOIN single_source_databases s
    ON p.parent_data_source_id IS NULL
   AND s.database_id = p.parent_database_id
LEFT JOIN data_sources ds
    ON ds.data_source_id = COALESCE(p.parent_data_source_id, s.data_source_id)
LEFT JOIN titles t ON t.page_id = p.page_id
LEFT JOIN statuses st ON st.page_id = p.page_id
LEFT JOIN {{staging.notion.user}} cu ON cu.user_id = p.created_by_id
LEFT JOIN {{staging.notion.user}} eu ON eu.user_id = p.last_edited_by_id
WHERE p.parent_type IN ('data_source_id', 'database_id')
