-- core.instagram_business.media_performance_report
-- Media Performance Report. Generates a media performance report for Instagram
-- Business integration. It combines metrics from the media_history and
-- media_insights tables to provide a comprehensive view of monthly media
-- performance. The report includes metrics such as total media posts, likes,
-- comments, carousel engagement, views and reach, reel likes, views and reach,
-- and feed engagement, views and reach.
--
-- Grain: account x month the media was posted. Each post counts once, with its
-- latest lifetime likes, comments and insights. Instagram now reports reel
-- plays as views, so total_reel_views replaces the old plays column, and
-- reports views instead of impressions for current posts, so
-- total_carousel_views and total_feed_views replace the impressions columns.
-- Feed engagement is the sum of a feed post's likes, comments, saves and
-- shares, which is how Instagram defines its total interactions.
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
          , carousel_album_views
          , carousel_album_reach
          , carousel_album_saved
          , reel_likes
          , reel_views
          , reel_reach
          , feed_views
          , feed_reach
        from
            {{raw.instagram.media_insights}}
    )
select
    mh.user_id
  , date_trunc(date(mh.timestamp), month) as month
  , count(distinct mh.id) as total_media_posts
  , sum(mh.like_count) as total_likes
  , sum(mh.comments_count) as total_comments
  , sum(mi.carousel_album_engagement) as total_carousel_engagement
  , sum(mi.carousel_album_views) as total_carousel_views
  , sum(mi.carousel_album_reach) as total_carousel_reach
  , sum(mi.carousel_album_saved) as total_carousel_saved
  , sum(mi.reel_likes) as total_reel_likes
  , sum(mi.reel_views) as total_reel_views
  , sum(mi.reel_reach) as total_reel_reach
  , sum(mi.feed_engagement) as total_feed_engagement
  , sum(mi.feed_views) as total_feed_views
  , sum(mi.feed_reach) as total_feed_reach
from
    latest_media mh
    left join insights mi on mi.id = mh.id
group by
    user_id
  , month
order by
    user_id
  , month desc
