-- core_instagram_business__media_performance_report
-- Media Performance Report. Generates a media performance report for Instagram
-- Business integration. It combines metrics from the media_history and
-- media_insights tables to provide a comprehensive view of monthly media
-- performance. The report includes metrics such as total media posts, likes,
-- comments, carousel engagement, impressions, reach, reel likes, plays, feed
-- engagement, impressions, and reach.
--
-- Grain: account x month the media was posted. Each post counts once, with its
-- latest lifetime likes, comments and insights. Instagram now reports reel
-- plays as views, so total_reel_views replaces the old plays column.
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
select
    mh.user_id
  , date_trunc(date(mh.timestamp), month) as month
  , count(distinct mh.id) as total_media_posts
  , sum(mh.like_count) as total_likes
  , sum(mh.comments_count) as total_comments
  , sum(mi.carousel_album_engagement) as total_carousel_engagement
  , sum(mi.carousel_album_impressions) as total_carousel_impressions
  , sum(mi.carousel_album_reach) as total_carousel_reach
  , sum(mi.carousel_album_saved) as total_carousel_saved
  , sum(mi.reel_likes) as total_reel_likes
  , sum(mi.reel_views) as total_reel_views
  , sum(mi.reel_reach) as total_reel_reach
  , sum(mi.feed_engagement) as total_feed_engagement
  , sum(mi.feed_impressions) as total_feed_impressions
  , sum(mi.feed_reach) as total_feed_reach
from
    latest_media mh
    left join {{ source('instagram', 'media_insights') }} mi on mi.id = mh.id
group by
    user_id
  , month
order by
    user_id
  , month desc
