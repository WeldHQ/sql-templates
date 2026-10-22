-- core.google_analytics_4.event_performance
-- Event Performance. This SQL template aggregates Google Analytics event data by
-- month, summarizing event counts, user counts, average events per user, and total
-- revenue for each event. It groups the data by period and event name, then orders
-- the results by event count in descending order.
--
-- From the weld.app template library. Not reconciled against Google Analytics 4;
-- check the output against the source before relying on it.

SELECT
  DATE_TRUNC(date, MONTH) AS period,  -- Change to 'DAY' for daily overview
  event_name,
  SUM(event_count) AS event_count,
  SUM(total_users) AS total_users,
  AVG(event_count_per_user) AS event_count_per_user,
  SUM(total_revenue) AS total_revenue
FROM
  {{raw.google_analytics_4.events_overview}}
GROUP BY
  period, event_name
ORDER BY
  event_count DESC
