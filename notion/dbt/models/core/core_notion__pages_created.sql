-- core_notion__pages_created
-- New database rows per day, data source and creator: how fast each tracker,
-- CRM or request log in Notion is filling up.
-- Grain: creation date (UTC) x data source x creator.
--
-- Archived and trashed pages are kept and counted separately, so a page created
-- and later deleted still shows up on the day it was created.

SELECT
    DATE(created_at)                 AS created_date,
    data_source_id,
    data_source_title,
    created_by_id,
    created_by_name,
    COUNT(*)                         AS pages_created,
    COUNTIF(is_archived)             AS pages_since_archived
FROM {{ ref('core_notion__database_pages') }}
GROUP BY 1, 2, 3, 4, 5
