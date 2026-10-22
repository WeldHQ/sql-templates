-- core_instagram_business__media_insights_deep_dive
-- Media Insights Deep Dive. Retrieves various metrics for different types of media
-- posts (carousel, reel, story, feed). It also calculates engagement rates for each
-- type of media. The template joins the media data with the media history table to
-- include additional information such as caption, timestamp, media type, likes
-- count, and comments count. The final result is sorted by month and media posted
-- date in descending order.
--
-- From the weld.app template library. Not reconciled against Instagram Business;
-- check the output against the source before relying on it.

with
    MediaDeepDive as (
        select
            id as media_id
          , date_trunc(_weld_synced_at, month) as month
          , -- Carousel Metrics
            carousel_album_engagement
          , carousel_album_impressions
          , carousel_album_reach
          , carousel_album_saved
          , carousel_album_video_views
          , -- Reel Metrics
            reel_comments
          , reel_likes
          , reel_plays
          , reel_reach
          , reel_saved
          , reel_shares
          , reel_total_interactions
          , -- Story Metrics
            story_exits
          , story_impressions
          , story_reach
          , story_replies
          , story_taps_back
          , story_taps_forward
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
            {{ source('instagram', 'media_insights') }}
    )
select
    md.*
  , mh.caption
  , mh.timestamp as media_posted_date
  , mh.media_type
  , mh.like_count
  , mh.comments_count
from
    MediaDeepDive md
    join {{ source('instagram', 'media_history') }} mh on md.media_id = mh.id
order by
    md.month desc
  , media_posted_date desc
