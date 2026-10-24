-- core_instagram_business__user_engagement_and_outreach_report
-- User Engagement and Outreach Report. Generates a report on user engagement and
-- outreach for an Instagram Business integration. For each account and month it
-- returns the average follower count and its change from the previous month, the
-- followers gained, the average daily reach, the profile link taps, and the
-- average likes, comments, feed views and feed reach per post. The result is
-- sorted by month and user ID.
--
-- Grain: account x month. The follower count is the average of the account
-- snapshots taken in that month: Instagram only returns the current count, so
-- the snapshot time is when it was measured. Followers gained and reach come from
-- Instagram's daily account insights, dated by the date Instagram returns with
-- each value; Instagram returns the daily follower count for the last 30 days
-- only. Profile link taps come from the daily aggregated account insights; days
-- with no taps have no row and count as zero. Post metrics count each post once,
-- with its latest lifetime counts, in the month it was posted; feed views and feed
-- reach are averaged over the posts that have them. The synced data has no
-- profile views or website clicks, so profile link taps take their place, and
-- feed views take the place of feed impressions, which Instagram no longer
-- reports for current posts.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Instagram Business; check the output against the source
-- before relying on it.

with
    MonthlyFollowers as (
        select
            id as user_id
          , date_trunc(date(_weld_synced_at), month) as month
          , avg(followers_count) as avg_followers_count
        from
            {{ source('instagram', 'user_history') }}
        group by
            user_id
          , month
    )
  , FollowerGrowth as (
        select
            user_id
          , month
          , avg_followers_count
          , coalesce(
                avg_followers_count - lag(avg_followers_count) over(
                    partition by user_id
                    order by
                        month
                )
              , 0
            ) as follower_growth
        from
            MonthlyFollowers
    )
  , MonthlyOutreach as (
        select
            ui.user_id
          , date_trunc(date(ui.date), month) as month
          , sum(ui.follower_count) as new_followers
          , avg(ui.reach) as avg_daily_reach
        from
            {{ source('instagram', 'user_insights') }} ui
        group by
            user_id
          , month
    )
  , MonthlyLinkTaps as (
        select
            user_id
          , date_trunc(date(start), month) as month
          , sum(safe_cast(value as int64)) as profile_links_taps
        from
            {{ source('instagram', 'user_aggregated_insights_per_day') }}
        where
            metric = 'profile_links_taps'
        group by
            user_id
          , month
    )
  , latest_media as (
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
  , MonthlyMediaEngagement as (
        select
            h.user_id
          , date_trunc(date(h.timestamp), month) as month
          , avg(h.like_count) as avg_like_count
          , avg(h.comments_count) as avg_comments_count
          , avg(i.feed_views) as avg_feed_views
          , avg(i.feed_reach) as avg_feed_reach
        from
            latest_media h
            left join {{ source('instagram', 'media_insights') }} i on i.id = h.id
        group by
            user_id
          , month
    )
  , AccountMonths as (
        select user_id, month from FollowerGrowth
        union distinct
        select user_id, month from MonthlyOutreach
        union distinct
        select user_id, month from MonthlyLinkTaps
        union distinct
        select user_id, month from MonthlyMediaEngagement
    )
select
    am.user_id
  , am.month
  , fg.avg_followers_count
  , fg.follower_growth
  , mo.new_followers
  , mo.avg_daily_reach
  , coalesce(mlt.profile_links_taps, 0) as profile_links_taps
  , mme.avg_like_count
  , mme.avg_comments_count
  , mme.avg_feed_views
  , mme.avg_feed_reach
from
    AccountMonths am
    left join FollowerGrowth fg on fg.user_id = am.user_id
    and fg.month = am.month
    left join MonthlyOutreach mo on mo.user_id = am.user_id
    and mo.month = am.month
    left join MonthlyLinkTaps mlt on mlt.user_id = am.user_id
    and mlt.month = am.month
    left join MonthlyMediaEngagement mme on mme.user_id = am.user_id
    and mme.month = am.month
order by
    am.month
  , am.user_id
