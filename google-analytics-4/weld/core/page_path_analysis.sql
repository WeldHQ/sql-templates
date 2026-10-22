-- core.google_analytics_4.page_path_analysis
-- Page Path Analysis. This SQL template aggregates Google Analytics data to provide
-- a monthly overview of page paths, including metrics such as screen page views,
-- total users, new users, event count, conversions, total revenue, and user
-- engagement duration, grouped by traffic source.
--
-- From the weld.app template library. Not reconciled against Google Analytics 4;
-- check the output against the source before relying on it.

SELECT
  DATE_TRUNC(pp.date, MONTH) AS period,  -- Change to 'DAY' for daily overview
  pp.page_path,
  ct.session_default_channel_grouping AS traffic_source,
  SUM(pp.screen_page_views) AS screen_page_views,
  SUM(pp.total_users) AS total_users,
  SUM(pp.new_users) AS new_users,
  SUM(pp.event_count) AS event_count,
  SUM(pp.conversions) AS conversions,
  SUM(pp.total_revenue) AS total_revenue,
  SUM(pp.user_engagement_duration) AS user_engagement_duration
FROM
  {{raw.google_analytics_4.page_path}} pp
LEFT JOIN
  {{raw.google_analytics_4.channel_traffic}} ct
ON
  pp.property_id = ct.property_id AND pp.date = ct.date
GROUP BY
  period, pp.page_path, traffic_source
ORDER BY
  screen_page_views DESC
