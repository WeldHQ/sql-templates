-- core_google_analytics_4__user_activity_overview
-- User Activity Overview. This SQL template aggregates monthly user activity data
-- from Google Analytics, including total users, new users, sessions, average
-- sessions per user, screen page views, and user engagement duration.
--
-- Grain: month x property. Months are calendar months, so the same month in
-- different years stays separate. GA4 reports users per day here, so
-- total_users is a sum of daily users (user-days), not unique users in the
-- month; sessions_per_user divides the month's sessions by that same sum.
--
-- From the weld.app template library, corrected. Not reconciled against Google
-- Analytics 4; check the output against the source before relying on it.

SELECT
  DATE_TRUNC(date, MONTH) AS month,
  property_id,
  SUM(total_users) AS total_users,
  SUM(new_users) AS new_users,
  SUM(sessions) AS sessions,
  SAFE_DIVIDE(SUM(sessions), SUM(total_users)) AS sessions_per_user,
  SUM(screen_page_views) AS screen_page_views,
  SUM(user_engagement_duration) AS user_engagement_duration
FROM
  {{ source('google_analytics_4', 'audience_overview') }}
GROUP BY
  month,
  property_id
ORDER BY
  month,
  property_id
