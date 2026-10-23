-- Within a month, site and query, the page impression shares must add up to 1.

SELECT month, site, query, SUM(query_impression_share) AS share_total
FROM {{ ref('core_google_search_console__query_page_monthly') }}
GROUP BY 1, 2, 3
HAVING SUM(impressions) > 0 AND ABS(SUM(query_impression_share) - 1) > 0.0001
