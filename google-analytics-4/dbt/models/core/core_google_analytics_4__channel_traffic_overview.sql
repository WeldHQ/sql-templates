-- core_google_analytics_4__channel_traffic_overview
-- Channel Traffic Overview. This SQL template provides a monthly overview of
-- channel traffic from Google Analytics, summarizing metrics such as total users,
-- sessions, engaged sessions, events per session, engagement rate, event count,
-- conversions, total revenue, and user engagement duration, grouped by channel.
--
-- From the weld.app template library. Not reconciled against Google Analytics 4;
-- check the output against the source before relying on it.

SELECT
  DATE_TRUNC(date, MONTH) AS period,  -- Change to 'DAY' for daily overview
  session_default_channel_grouping AS channel,
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
  {{ source('google_analytics_4', 'channel_traffic') }}
GROUP BY
  period, channel
ORDER BY
  total_users DESC
