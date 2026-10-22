-- core_instagram_business__engagement_metric_analysis
-- Engagment Metric Analysis. Calculates various engagement metrics for Instagram
-- Business accounts on a monthly basis. It retrieves data such as the total number
-- of media posts, likes, comments, feed engagement, carousel engagement, reel
-- likes, reel comments, story replies, and story exits. Additionally, it calculates
-- average engagement per post metrics, including average likes, comments, feed
-- engagement, carousel engagement, reel likes, and reel comments per post. The
-- results are ordered by month in descending order.
--
-- From the weld.app template library. Not reconciled against Instagram Business;
-- check the output against the source before relying on it.

with
    MonthlyEngagementData as (
        select
            format_date('%Y-%m', date(mh._weld_synced_at)) as month
          , count(distinct mh.id) as total_media_posts
          , sum(mh.like_count) as total_likes
          , sum(mh.comments_count) as total_comments
          , sum(mi.feed_engagement) as total_feed_engagement
          , sum(mi.carousel_album_engagement) as total_carousel_engagement
          , sum(mi.reel_likes) as total_reel_likes
          , sum(mi.reel_comments) as total_reel_comments
          , sum(mi.story_replies) as total_story_replies
          , sum(mi.story_exits) as total_story_exits
        from
            {{ source('instagram', 'media_history') }} mh
            left join {{ source('instagram', 'media_insights') }} mi on mh.id = mi.id
        group by
            month
    )
select
    month
  , total_media_posts
  , total_likes
  , total_comments
  , total_feed_engagement
  , total_carousel_engagement
  , total_reel_likes
  , total_reel_comments
  , total_story_replies
  , total_story_exits
  , -- Engagement per post metrics
    round(total_likes / nullif(total_media_posts, 0), 2) as avg_likes_per_post
  , round(total_comments / nullif(total_media_posts, 0), 2) as avg_comments_per_post
  , round(
        total_feed_engagement / nullif(total_media_posts, 0)
      , 2
    ) as avg_feed_engagement_per_post
  , round(
        total_carousel_engagement / nullif(total_media_posts, 0)
      , 2
    ) as avg_carousel_engagement_per_post
  , round(total_reel_likes / nullif(total_media_posts, 0), 2) as avg_reel_likes_per_post
  , round(
        total_reel_comments / nullif(total_media_posts, 0)
      , 2
    ) as avg_reel_comments_per_post
from
    MonthlyEngagementData
order by
    month desc
