-- core_google_search_console__query_performance_daily
-- The Queries tab of the Performance report, by day.
--
-- Grain: date_day x site x query. Dates are Pacific Time.
-- Depends on: staging.google_search_console.query_analytics
--
-- Aggregated by property, so a query counts once per search even when several of
-- your pages showed. Anonymized queries are absent, so totals sit below
-- site_performance_daily. Position is impression-weighted across countries and
-- devices; re-aggregate with weighted_position_sum, never by averaging.

SELECT
    date_day,
    site,
    query,
    SUM(clicks)                                              AS clicks,
    SUM(impressions)                                         AS impressions,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))               AS ctr,
    SAFE_DIVIDE(SUM(position * impressions), SUM(impressions)) AS average_position,
    SUM(position * impressions)                              AS weighted_position_sum,
    SUM(IF(device = 'mobile', clicks, 0))                    AS mobile_clicks,
    SUM(IF(device = 'mobile', impressions, 0))               AS mobile_impressions
FROM {{ ref('stg_google_search_console__query_analytics') }}
GROUP BY 1, 2, 3
