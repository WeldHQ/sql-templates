-- core_instagram_business__user_engagement_and_outreach_report
-- User Engagement and Outreach Report. Generates a report on user engagement and
-- outreach for an Instagram Business integration. It combines data from various
-- tables to calculate average follower count, profile views, website clicks, like
-- count, comments count, feed impressions, and feed reach on a monthly basis. The
-- result is sorted by month and user ID.
--
-- From the weld.app template library. Not reconciled against Instagram Business;
-- check the output against the source before relying on it.

with
    MonthlyFollowers as (
        select
            date_trunc(_weld_synced_at, month) month
          , id as user_id
          , avg(followers_count) as avg_followers_count
        from
            {{ source('instagram', 'user_history') }}
        group by
            month
          , user_id
    )
  , MonthlyProfileEngagement as (
        select
            date_trunc(_weld_synced_at, month) month
          , user_id
          , avg(profile_views) as avg_profile_views
          , avg(website_clicks) as avg_website_clicks
        from
            {{ source('instagram', 'user_insights') }}
        group by
            month
          , user_id
    )
  , MonthlyMediaEngagement as (
        select
            date_trunc(h._weld_synced_at, month) month
          , user_id
          , avg(like_count) as avg_like_count
          , avg(comments_count) as avg_comments_count
          , avg(feed_impressions) as avg_feed_impressions
          , avg(feed_reach) as avg_feed_reach
        from
            {{ source('instagram', 'media_history') }} h
            left join {{ source('instagram', 'media_insights') }} i on i.id = h.id
            and date_trunc(i._weld_synced_at, month) = date_trunc(h._weld_synced_at, month)
        group by
            month
          , user_id
    )
select
    mf.month
  , mf.avg_followers_count
  , coalesce(
        mf.avg_followers_count - lag(mf.avg_followers_count) over(
            partition by mf.user_id
            order by
                mf.month
        )
      , 0
    ) as follower_growth
  , mpe.avg_profile_views
  , mpe.avg_website_clicks
  , mme.avg_like_count
  , mme.avg_comments_count
  , mme.avg_feed_impressions
  , mme.avg_feed_reach
from
    MonthlyFollowers mf
    join MonthlyProfileEngagement mpe on mf.month = mpe.month
    and mf.user_id = mpe.user_id
    join MonthlyMediaEngagement mme on mf.month = mme.month
    and mf.user_id = mme.user_id
order by
    mf.month
  , mf.user_id
