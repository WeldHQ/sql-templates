-- core_instagram_business__growth_analysis
-- Growth Analysis. Calculates the growth rates of various metrics for an Instagram
-- Business account. It retrieves monthly data on average followers, average
-- follows, total feed engagement, total carousel engagement, and total reel likes.
-- It then calculates the growth rate percentages for each metric compared to the
-- previous month. The results are sorted by month in descending order.
--
-- From the weld.app template library. Not reconciled against Instagram Business;
-- check the output against the source before relying on it.

with
    MonthlyGrowthData as (
        select
            format_date('%Y-%m', date(uh._weld_synced_at)) as month
          , avg(uh.followers_count) as avg_followers
          , avg(uh.follows_count) as avg_follows
          , sum(mi.feed_engagement) as total_feed_engagement
          , sum(mi.carousel_album_engagement) as total_carousel_engagement
          , sum(mi.reel_likes) as total_reel_likes
        from
            {{ source('instagram', 'user_history') }} uh
            left join {{ source('instagram', 'media_history') }} h on h.user_id = uh.id
            left join {{ source('instagram', 'media_insights') }} mi on mi.id = h.id
        group by
            month
    )
  , GrowthRates as (
        select
            month
          , avg_followers
          , avg_follows
          , total_feed_engagement
          , total_carousel_engagement
          , total_reel_likes
          , lag(avg_followers, 1) over(
                order by
                    month
            ) as last_month_followers
          , lag(avg_follows, 1) over(
                order by
                    month
            ) as last_month_follows
          , lag(total_feed_engagement, 1) over(
                order by
                    month
            ) as last_month_feed_engagement
          , lag(total_carousel_engagement, 1) over(
                order by
                    month
            ) as last_month_carousel_engagement
          , lag(total_reel_likes, 1) over(
                order by
                    month
            ) as last_month_reel_likes
        from
            MonthlyGrowthData
    )
select
    month
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
    month desc
