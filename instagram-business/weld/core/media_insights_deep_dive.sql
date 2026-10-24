-- core.instagram_business.media_insights_deep_dive
-- Media Insights Deep Dive. Retrieves various metrics for different types of media
-- posts (carousel, reel, story, feed). It also calculates engagement rates for each
-- type of media. The template joins the media data with the media history table to
-- include additional information such as caption, timestamp, media type, likes
-- count, and comments count. The final result is sorted by month and media posted
-- date in descending order.
--
-- Grain: one row per media post, dated by the month it was posted. Insights
-- are lifetime totals as of the latest sync. Instagram has renamed some
-- metrics: reel plays are now views, and story exits and taps are reported as
-- story_tap_exit, story_tap_back and story_tap_forward; the output keeps the
-- older column names where the meaning is the same.
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
  , MediaDeepDive as (
        select
            id as media_id
          , -- Carousel Metrics
            carousel_album_engagement
          , carousel_album_impressions
          , carousel_album_reach
          , carousel_album_saved
          , carousel_album_video_views
          , -- Reel Metrics
            reel_comments
          , reel_likes
          , reel_views
          , reel_reach
          , reel_saved
          , reel_shares
          , reel_total_interactions
          , -- Story Metrics
            story_tap_exit as story_exits
          , story_impressions
          , story_reach
          , story_replies
          , story_tap_back as story_taps_back
          , story_tap_forward as story_taps_forward
          , -- Feed Metrics
            feed_engagement
          , feed_impressions
          , feed_reach
          , feed_saved
          , feed_video_views
          , -- Engagement Rates (Simple calculations as examples; can be expanded as needed)
            case
                when carousel_album_impressions != 0 then carousel_album_engagement / carousel_album_impressions * 100
                else null
            end as carousel_engagement_rate
          , case
                when reel_reach != 0 then reel_likes / reel_reach * 100
                else null
            end as reel_like_rate
          , case
                when feed_impressions != 0 then feed_engagement / feed_impressions * 100
                else null
            end as feed_engagement_rate
        from
            {{raw.instagram.media_insights}}
    )
select
    date_trunc(date(mh.timestamp), month) as month
  , md.*
  , mh.caption
  , mh.timestamp as media_posted_date
  , mh.media_type
  , mh.like_count
  , mh.comments_count
from
    MediaDeepDive md
    join latest_media mh on md.media_id = mh.id
order by
    month desc
  , media_posted_date desc
