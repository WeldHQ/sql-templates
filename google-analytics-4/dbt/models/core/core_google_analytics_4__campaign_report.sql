-- core_google_analytics_4__campaign_report
-- Campaign Report. This SQL template generates a monthly summary report of campaign
-- performance metrics from Google Analytics data. It aggregates data such as total
-- users, sessions, engaged sessions, events per session, engagement rate, event
-- count, conversions, total revenue, and user engagement duration. The results are
-- ordered by period and total users in descending order.
--
-- From the weld.app template library. Not reconciled against Google Analytics 4;
-- check the output against the source before relying on it.

WITH
  campaign_stats AS (
    SELECT
      DATE_TRUNC(date, MONTH) AS period,  -- Change to 'DAY' for daily overview
      session_campaign_name,
      SUM(total_users) AS total_users,
      SUM(sessions) AS sessions,
      SUM(engaged_sessions) AS engaged_sessions,
      AVG(events_per_session) AS events_per_session,
      AVG(engagement_rate) AS engagement_rate,
      SUM(event_count) AS event_count,
      SUM(conversions) AS conversions,
      SUM(total_revenue) AS total_revenue,
      SUM(user_engagement_duration) AS user_engagement_duration
    FROM
      {{ source('google_analytics_4', 'campaign_performance') }}
    GROUP BY
      period, session_campaign_name
  )

SELECT
  period,
  session_campaign_name AS campaign,
  total_users,
  sessions,
  engaged_sessions,
  events_per_session,
  engagement_rate,
  event_count,
  conversions,
  total_revenue,
  user_engagement_duration
FROM
  campaign_stats
ORDER BY
  period DESC, total_users DESC
