-- core.instagram_business.profile_overview_report
-- Profile Overview Report. Profile overview report for Instagram Business
-- integration. It combines data from different tables to calculate average follows
-- count, average followers count, average profile views, and average website clicks
-- for each user on a monthly basis. The results are then ordered by month.
--
-- From the weld.app template library. Not reconciled against Instagram Business;
-- check the output against the source before relying on it.

WITH MonthlyData AS (
  SELECT
    DATE_TRUNC( _weld_synced_at,month) AS month,
    AVG(follows_count) AS avg_follows_count,
    AVG(followers_count) AS avg_followers_count,
    id as user_id
  FROM
   {{raw.instagram.user_history}}
  GROUP BY
    month, user_id
),

MonthlyProfileViews AS (
  SELECT
    DATE_TRUNC( _weld_synced_at,month) AS month,
    AVG(profile_views) AS avg_profile_views,
    user_id
  FROM
     {{raw.instagram.user_insights}}
  GROUP BY
    month, user_id
),

MonthlyWebsiteClicks AS (
  SELECT
    DATE_TRUNC( _weld_synced_at,month) AS month,
    AVG(website_clicks) AS avg_website_clicks,
    user_id
  FROM
   {{raw.instagram.user_insights}}
  GROUP BY
    month, user_id
)

SELECT
  md.month,
  md.avg_follows_count,
  md.avg_followers_count,
  mpv.avg_profile_views,
  mwc.avg_website_clicks
FROM
  MonthlyData md
JOIN
  MonthlyProfileViews mpv
ON
  md.month = mpv.month AND md.user_id = mpv.user_id
JOIN
  MonthlyWebsiteClicks mwc
ON
  md.month = mwc.month AND md.user_id = mwc.user_id
ORDER BY
  md.month
