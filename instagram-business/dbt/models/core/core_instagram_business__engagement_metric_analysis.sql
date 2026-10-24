-- core_instagram_business__engagement_metric_analysis
-- Engagment Metric Analysis. Calculates various engagement metrics for Instagram
-- Business accounts on a monthly basis. It retrieves data such as the total number
-- of media posts, likes, comments, feed engagement, carousel engagement, reel
-- likes, reel comments, story replies, and story exits. Additionally, it calculates
-- average engagement per post metrics, including average likes, comments, feed
-- engagement, carousel engagement, reel likes, and reel comments per post. The
-- results are ordered by month in descending order.
--
-- Grain: month the media was posted. Each post counts once, with its latest
-- lifetime likes, comments and insights, so a month's totals keep growing
-- while its posts collect engagement. Instagram reports story exits as
-- story_tap_exit. Feed engagement is the sum of a feed post's likes, comments,
-- saves and shares, which is how Instagram defines its total interactions.
--
-- From the weld.app template library, corrected. Not reconciled against
-- Instagram Business; check the output against the source before relying on it.

with
    latest_media as (
        -- media_history keeps a snapshot of each post per sync; the latest one
        -- carries the current like and comment counts
        select
            *
        from
            {{ source('instagram', 'media_history') }}
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
  , insights as (
        -- Instagram's total interactions for a post are its likes, comments,
        -- saves and shares. Feed posts are synced with those counts but without
        -- the total, so feed engagement is their sum; carousels use the synced
        -- total and fall back to the same sum.
        select
            id
          , case
                when coalesce(feed_likes, feed_comments, feed_saved, feed_shares) is not null
                    then ifnull(feed_likes, 0) + ifnull(feed_comments, 0) + ifnull(feed_saved, 0) + ifnull(feed_shares, 0)
                else feed_engagement
            end as feed_engagement
          , coalesce(
                carousel_album_engagement
              , case
                    when coalesce(carousel_album_likes, carousel_album_comments, carousel_album_saved, carousel_album_shares) is not null
                        then ifnull(carousel_album_likes, 0) + ifnull(carousel_album_comments, 0) + ifnull(carousel_album_saved, 0) + ifnull(carousel_album_shares, 0)
                end
            ) as carousel_album_engagement
          , reel_likes
          , reel_comments
          , story_replies
          , story_tap_exit
        from
            {{ source('instagram', 'media_insights') }}
    )
  , MonthlyEngagementData as (
        select
            format_date('%Y-%m', date(mh.timestamp)) as month
          , count(distinct mh.id) as total_media_posts
          , sum(mh.like_count) as total_likes
          , sum(mh.comments_count) as total_comments
          , sum(mi.feed_engagement) as total_feed_engagement
          , sum(mi.carousel_album_engagement) as total_carousel_engagement
          , sum(mi.reel_likes) as total_reel_likes
          , sum(mi.reel_comments) as total_reel_comments
          , sum(mi.story_replies) as total_story_replies
          , sum(mi.story_tap_exit) as total_story_exits
        from
            latest_media mh
            left join insights mi on mh.id = mi.id
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
