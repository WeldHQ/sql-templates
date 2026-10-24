-- core.instagram_business.growth_analysis
-- Growth Analysis. Calculates the growth rates of various metrics for an Instagram
-- Business account. It retrieves monthly data on average followers, average
-- follows, total feed engagement, total carousel engagement, and total reel likes.
-- It then calculates the growth rate percentages for each metric compared to the
-- previous month. The results are sorted by month in descending order.
--
-- Grain: account x month. Followers and follows are the average of the
-- account snapshots Weld took in that month (the snapshot time is when the
-- count was read). Engagement is the latest lifetime engagement of the posts
-- published in that month. Growth rates compare each month with the
-- account's previous month in the data.
--
-- From the weld.app template library, corrected. Not reconciled against
-- Instagram Business; check the output against the source before relying on it.

with
    MonthlyFollowers as (
        select
            id as user_id
          , format_date('%Y-%m', date(_weld_synced_at)) as month
          , avg(followers_count) as avg_followers
          , avg(follows_count) as avg_follows
        from
            {{raw.instagram.user_history}}
        group by
            user_id
          , month
    )
  ,
    latest_media as (
        -- media_history keeps a snapshot of each post per sync; the latest one
        -- carries the current like and comment counts
        select
            *
        from
            {{raw.instagram.media_history}}
        where
            true
        qualify
            row_number() over(
                partition by
                    id
                order by
                    _weld_synced_at desc
            ) = 1
    )
  , MonthlyEngagement as (
        select
            mh.user_id
          , format_date('%Y-%m', date(mh.timestamp)) as month
          , sum(mi.feed_engagement) as total_feed_engagement
          , sum(mi.carousel_album_engagement) as total_carousel_engagement
          , sum(mi.reel_likes) as total_reel_likes
        from
            latest_media mh
            left join {{raw.instagram.media_insights}} mi on mi.id = mh.id
        group by
            user_id
          , month
    )
  , MonthlyGrowthData as (
        select
            coalesce(f.user_id, e.user_id) as user_id
          , coalesce(f.month, e.month) as month
          , f.avg_followers
          , f.avg_follows
          , e.total_feed_engagement
          , e.total_carousel_engagement
          , e.total_reel_likes
        from
            MonthlyFollowers f
            full join MonthlyEngagement e on e.user_id = f.user_id
            and e.month = f.month
    )
  , GrowthRates as (
        select
            user_id
          , month
          , avg_followers
          , avg_follows
          , total_feed_engagement
          , total_carousel_engagement
          , total_reel_likes
          , lag(avg_followers, 1) over(by_user) as last_month_followers
          , lag(avg_follows, 1) over(by_user) as last_month_follows
          , lag(total_feed_engagement, 1) over(by_user) as last_month_feed_engagement
          , lag(total_carousel_engagement, 1) over(by_user) as last_month_carousel_engagement
          , lag(total_reel_likes, 1) over(by_user) as last_month_reel_likes
        from
            MonthlyGrowthData
        window
            by_user as (
                partition by
                    user_id
                order by
                    month
            )
    )
select
    user_id
  , month
  , round(
        (avg_followers - last_month_followers) / nullif(last_month_followers, 0) * 100
      , 2
    ) as followers_growth_rate_percentage
  , round(
        (avg_follows - last_month_follows) / nullif(last_month_follows, 0) * 100
      , 2
    ) as follows_growth_rate_percentage
  , round(
        (total_feed_engagement - last_month_feed_engagement) / nullif(last_month_feed_engagement, 0) * 100
      , 2
    ) as feed_engagement_growth_rate_percentage
  , round(
        (
            total_carousel_engagement - last_month_carousel_engagement
        ) / nullif(last_month_carousel_engagement, 0) * 100
      , 2
    ) as carousel_engagement_growth_rate_percentage
  , round(
        (total_reel_likes - last_month_reel_likes) / nullif(last_month_reel_likes, 0) * 100
      , 2
    ) as reel_likes_growth_rate_percentage
from
    GrowthRates
order by
    user_id
  , month desc
