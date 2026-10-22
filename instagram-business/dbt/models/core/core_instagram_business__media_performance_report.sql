-- core_instagram_business__media_performance_report
-- Media Performance Report. Generates a media performance report for Instagram
-- Business integration. It combines metrics from the media_history and
-- media_insights tables to provide a comprehensive view of monthly media
-- performance. The report includes metrics such as total media posts, likes,
-- comments, carousel engagement, impressions, reach, reel likes, plays, feed
-- engagement, impressions, and reach.
--
-- From the weld.app template library. Not reconciled against Instagram Business;
-- check the output against the source before relying on it.

with
    MonthlyMediaMetrics as (
        -- Aggregating metrics from media_history
        select
            user_id
          , date_trunc(_weld_synced_at, month) month
          , count(distinct id) as total_media_posts
          , sum(like_count) as total_likes
          , sum(comments_count) as total_comments
        from
            {{ source('instagram', 'media_history') }}
        group by
            user_id
          , month
    )
  , MonthlyMediaInsightsMetrics as (
        -- Aggregating metrics from media_insights
        select
            h.user_id
          , date_trunc(i._weld_synced_at, month) month
          , sum(carousel_album_engagement) as total_carousel_engagement
          , sum(carousel_album_impressions) as total_carousel_impressions
          , sum(carousel_album_reach) as total_carousel_reach
          , sum(carousel_album_saved) as total_carousel_saved
          , sum(reel_likes) as total_reel_likes
          , sum(reel_plays) as total_reel_plays
          , sum(reel_reach) as total_reel_reach
          , sum(feed_engagement) as total_feed_engagement
          , sum(feed_impressions) as total_feed_impressions
          , sum(feed_reach) as total_feed_reach
        from
            {{ source('instagram', 'media_insights') }} i
            left join {{ source('instagram', 'media_history') }} h on i.id = h.id
        group by
            month
          , h.user_id
    ) -- Merging the two aggregated tables to provide a comprehensive view
select
    mmm.user_id
  , mmm.month
  , mmm.total_media_posts
  , mmm.total_likes
  , mmm.total_comments
  , mmim.total_carousel_engagement
  , mmim.total_carousel_impressions
  , mmim.total_carousel_reach
  , mmim.total_carousel_saved
  , mmim.total_reel_likes
  , mmim.total_reel_plays
  , mmim.total_reel_reach
  , mmim.total_feed_engagement
  , mmim.total_feed_impressions
  , mmim.total_feed_reach
from
    MonthlyMediaMetrics mmm
    join MonthlyMediaInsightsMetrics mmim on mmm.user_id = mmim.user_id
    and mmm.month = mmim.month
order by
    mmm.user_id
  , mmm.month desc
