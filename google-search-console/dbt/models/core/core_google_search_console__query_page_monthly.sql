-- core_google_search_console__query_page_monthly
-- Which pages rank for which query, per month, and how a query's clicks split
-- across your pages. The usual way to spot two pages competing for one query.
--
-- Grain: month x site x query x page. Month is the first day, Pacific Time.
-- Depends on: staging.google_search_console.query_page_analytics
--
-- Shares are of the query's clicks and impressions across your pages in the
-- month. A query with several pages each holding a real share of impressions is a
-- cannibalisation candidate. Anonymized queries are absent.

WITH by_page AS (
    SELECT
        DATE_TRUNC(date_day, MONTH)         AS month,
        site,
        query,
        page,
        SUM(clicks)                         AS clicks,
        SUM(impressions)                    AS impressions,
        SUM(position * impressions)         AS weighted_position_sum
    FROM {{ ref('stg_google_search_console__query_page_analytics') }}
    GROUP BY 1, 2, 3, 4
)

SELECT
    month,
    site,
    query,
    page,
    clicks,
    impressions,
    SAFE_DIVIDE(clicks, impressions)                         AS ctr,
    SAFE_DIVIDE(weighted_position_sum, impressions)          AS average_position,
    weighted_position_sum,
    SAFE_DIVIDE(clicks, SUM(clicks) OVER (PARTITION BY month, site, query))           AS query_click_share,
    SAFE_DIVIDE(impressions, SUM(impressions) OVER (PARTITION BY month, site, query)) AS query_impression_share,
    COUNT(*) OVER (PARTITION BY month, site, query)                                   AS ranking_pages
FROM by_page
