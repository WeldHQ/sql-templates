-- core.google_analytics_4.page_path_analysis
-- Page Path Analysis. This SQL template aggregates Google Analytics data to provide
-- a monthly overview of page paths, including metrics such as screen page views,
-- total users, new users, event count, conversions, total revenue, and user
-- engagement duration.
--
-- Grain: month x property x page path. The page path report has no channel
-- dimension, so it cannot be split by traffic source; joining the channel
-- report on date would repeat every page once per channel and multiply the
-- sums. Pages by channel need a report that carries both dimensions, such as
-- a custom report with page path and session default channel group.
-- total_users is a sum of daily users, not unique users.
--
-- From the weld.app template library, corrected. Not reconciled against Google
-- Analytics 4; check the output against the source before relying on it.

SELECT
  DATE_TRUNC(date, MONTH) AS period,  -- change to DAY for a daily overview
  property_id,
  page_path,
  SUM(screen_page_views) AS screen_page_views,
  SUM(total_users) AS total_users,
  SUM(new_users) AS new_users,
  SUM(event_count) AS event_count,
  SUM(conversions) AS conversions,
  SUM(total_revenue) AS total_revenue,
  SUM(user_engagement_duration) AS user_engagement_duration
FROM
  {{raw.google_analytics_4.page_path}}
GROUP BY
  period,
  property_id,
  page_path
ORDER BY
  screen_page_views DESC
