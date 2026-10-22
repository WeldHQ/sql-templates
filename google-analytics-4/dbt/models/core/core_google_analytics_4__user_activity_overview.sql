-- core_google_analytics_4__user_activity_overview
-- User Activity Overview. This SQL template aggregates monthly user activity data
-- from Google Analytics, including total users, new users, sessions, average
-- sessions per user, screen page views, and user engagement duration.
--
-- From the weld.app template library. Not reconciled against Google Analytics 4;
-- check the output against the source before relying on it.

SELECT
  EXTRACT(MONTH FROM date) AS month,
  SUM(total_users) AS total_users,
  SUM(new_users) AS new_users,
  SUM(sessions) AS sessions,
  AVG(sessions_per_user) AS sessions_per_user,
  SUM(screen_page_views) AS screen_page_views,
  SUM(user_engagement_duration) AS user_engagement_duration
FROM
  {{ source('google_analytics_4', 'audience_overview') }}
GROUP BY
  month
ORDER BY
  month
