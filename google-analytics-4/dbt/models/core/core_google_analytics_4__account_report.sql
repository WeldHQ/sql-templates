-- core_google_analytics_4__account_report
-- Account Report. This SQL template generates a comprehensive account report by
-- aggregating user statistics, campaign performance, and event data from Google
-- Analytics. It combines these metrics to provide insights on total users, new
-- users, sessions, user engagement, campaign details, and event revenue for each
-- day. The results are ordered by date in descending order.
--
-- From the weld.app template library. Not reconciled against Google Analytics 4;
-- check the output against the source before relying on it.

WITH
  user_stats AS (
    SELECT
      EXTRACT(DATE FROM date) AS date_day,
      property_id,
      SUM(total_users) AS total_users,
      SUM(new_users) AS new_users,
      SUM(sessions) AS sessions,
      SUM(user_engagement_duration) AS user_engagement_duration
    FROM
      {{ source('google_analytics_4', 'audience_overview') }}
    GROUP BY
      date_day, property_id
  ),
  campaign_stats AS (
    SELECT
      property_id,
      session_campaign_name,
      EXTRACT(DATE FROM date) AS date_day,
      SUM(total_users) AS campaign_total_users,
      SUM(sessions) AS campaign_sessions,
      SUM(engaged_sessions) AS campaign_engaged_sessions,
      AVG(engagement_rate) AS campaign_engagement_rate,
      SUM(event_count) AS campaign_event_count,
      SUM(total_revenue) AS campaign_total_revenue
    FROM
      {{ source('google_analytics_4', 'campaign_performance') }}
    GROUP BY
      property_id, session_campaign_name, date_day
  ),
  event_stats AS (
    SELECT
      EXTRACT(DATE FROM date) AS date_day,
      SUM(event_count) AS event_total_count,
      SUM(total_revenue) AS event_total_revenue
    FROM
      {{ source('google_analytics_4', 'events_overview') }}
    GROUP BY
      date_day
  )
SELECT
  us.date_day,
  us.property_id AS account_id,
  us.total_users,
  us.new_users,
  us.sessions,
  us.user_engagement_duration,
  cs.session_campaign_name AS campaign_name,
  cs.campaign_total_users,
  cs.campaign_sessions,
  cs.campaign_engaged_sessions,
  cs.campaign_engagement_rate,
  cs.campaign_event_count,
  cs.campaign_total_revenue,
  es.event_total_count,
  es.event_total_revenue
FROM
  user_stats us
  LEFT JOIN campaign_stats cs ON us.date_day = cs.date_day AND us.property_id = cs.property_id
  LEFT JOIN event_stats es ON us.date_day = es.date_day
ORDER BY
  us.date_day DESC
