-- Query-level data is the property total minus anonymized queries, so it can be
-- smaller than the site total but never larger. A negative gap means the site and
-- query tables cover different search types, sites or date ranges.

SELECT date_day, site, clicks, query_clicks, impressions, query_impressions
FROM {{ ref('core_google_search_console__site_performance_daily') }}
WHERE anonymized_clicks < 0 OR anonymized_impressions < 0
