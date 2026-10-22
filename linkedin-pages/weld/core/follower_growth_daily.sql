-- core.linkedin_pages.follower_growth_daily
-- The Followers section of LinkedIn Page analytics: new followers per day, split
-- organic and paid, with an estimated follower total for each day.
--
-- Grain: date_day x organization_id. Days are UTC.
-- Depends on: staging.linkedin_pages.follower_gains_daily, .total_follower_count
--
-- LinkedIn gives daily gains and a current total, but no daily total. The total
-- for each day is rebuilt backwards: today's count minus every gain after that
-- day. That makes `followers_estimated` an estimate:
--   - the current count is taken at sync time, while gains stop two days before
--     today, so the last day already includes those one or two days of gains;
--   - LinkedIn does not document whether gains are net of unfollows. If they are
--     not, the estimate drifts above the true count the further back you go.
-- Use it for the shape of the curve. Sum the gain columns for growth over a
-- period; never sum followers_estimated.

WITH gains AS (
    SELECT
        date_day,
        organization_id,
        organization_name,
        organic_follower_gain,
        paid_follower_gain,
        organic_follower_gain + paid_follower_gain AS follower_gain
    FROM {{staging.linkedin_pages.follower_gains_daily}}
)

SELECT
    g.date_day,
    g.organization_id,
    g.organization_name,
    g.organic_follower_gain,
    g.paid_follower_gain,
    g.follower_gain,
    t.follower_count                                                  AS current_follower_count,
    t.follower_count - COALESCE(SUM(g.follower_gain) OVER (
        PARTITION BY g.organization_id
        ORDER BY g.date_day
        ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
    ), 0)                                                             AS followers_estimated
FROM gains g
-- One row per organization after staging, so this cannot fan out.
LEFT JOIN {{staging.linkedin_pages.total_follower_count}} t USING (organization_id)
