-- pages_created sums back to the number of pages in database_pages.
-- Returns zero rows when they agree.

SELECT
    (SELECT COUNT(*) FROM {{ ref('core_notion__database_pages') }})        AS pages,
    (SELECT SUM(pages_created) FROM {{ ref('core_notion__pages_created') }}) AS pages_created
FROM (SELECT 1)
WHERE (SELECT COUNT(*) FROM {{ ref('core_notion__database_pages') }})
   != (SELECT COALESCE(SUM(pages_created), 0) FROM {{ ref('core_notion__pages_created') }})
