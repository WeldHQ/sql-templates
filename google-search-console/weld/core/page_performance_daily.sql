-- core.google_search_console.page_performance_daily
-- The Pages tab of the Performance report, by day.
--
-- Grain: date_day x site x page. Dates are Pacific Time.
-- Depends on: staging.google_search_console.page_analytics
--
-- Aggregated by page: when two of your pages appear in one search, each gets the
-- impression, so impressions summed over pages exceed the site total. That is
-- how Search Console counts it too. Clicks still go to the one page clicked.
-- Page tables include anonymized queries, unlike the query tables.

SELECT
    date_day,
    site,
    page,
    SUM(clicks)                                              AS clicks,
    SUM(impressions)                                         AS impressions,
    SAFE_DIVIDE(SUM(clicks), SUM(impressions))               AS ctr,
    SAFE_DIVIDE(SUM(position * impressions), SUM(impressions)) AS average_position,
    SUM(position * impressions)                              AS weighted_position_sum,
    SUM(IF(device = 'mobile', clicks, 0))                    AS mobile_clicks,
    SUM(IF(device = 'mobile', impressions, 0))               AS mobile_impressions
FROM {{staging.google_search_console.page_analytics}}
GROUP BY 1, 2, 3
