-- database_pages has one row per page. Returns zero rows when it holds. A failure
-- means a join to data sources, titles or statuses fanned out.

SELECT page_id, COUNT(*) AS n
FROM {{ ref('core_notion__database_pages') }}
GROUP BY 1
HAVING COUNT(*) > 1
