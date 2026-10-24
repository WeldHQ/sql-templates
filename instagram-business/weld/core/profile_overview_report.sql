-- core.instagram_business.profile_overview_report
-- Profile Overview Report. Profile overview report for Instagram Business
-- integration. For each account and month it returns the average follows and
-- followers count, the followers gained, the average daily reach and the number of
-- taps on the links in the profile. The results are ordered by account and month.
--
-- Grain: account x month. Follows and followers are the average of the account
-- snapshots taken in that month: Instagram only returns the current count, so
-- the snapshot time is when it was measured. Followers gained and reach come from
-- Instagram's daily account insights and are dated by the date Instagram returns
-- with each value. Instagram returns the daily follower count for the last 30
-- days only, so older months show followers gained only if a sync collected them
-- at the time. Profile link taps come from the daily aggregated account insights;
-- days with no taps have no row and count as zero. The synced account insights
-- have no profile views or website clicks; profile link taps are the closest
-- metric, so the report returns those instead.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Instagram Business; check the output against the source
-- before relying on it.

with
    MonthlyProfile as (
        select
            id as user_id
          , date_trunc(date(_weld_synced_at), month) as month
          , avg(follows_count) as avg_follows_count
          , avg(followers_count) as avg_followers_count
        from
            {{raw.instagram.user_history}}
        group by
            user_id
          , month
    )
  , MonthlyInsights as (
        select
            ui.user_id
          , date_trunc(date(ui.date), month) as month
          , sum(ui.follower_count) as new_followers
          , avg(ui.reach) as avg_daily_reach
        from
            {{raw.instagram.user_insights}} ui
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
            {{raw.instagram.user_aggregated_insights_per_day}}
        where
            metric = 'profile_links_taps'
        group by
            user_id
          , month
    )
  , AccountMonths as (
        select user_id, month from MonthlyProfile
        union distinct
        select user_id, month from MonthlyInsights
        union distinct
        select user_id, month from MonthlyLinkTaps
    )
select
    am.user_id
  , am.month
  , mp.avg_follows_count
  , mp.avg_followers_count
  , mi.new_followers
  , mi.avg_daily_reach
  , coalesce(mlt.profile_links_taps, 0) as profile_links_taps
from
    AccountMonths am
    left join MonthlyProfile mp on mp.user_id = am.user_id
    and mp.month = am.month
    left join MonthlyInsights mi on mi.user_id = am.user_id
    and mi.month = am.month
    left join MonthlyLinkTaps mlt on mlt.user_id = am.user_id
    and mlt.month = am.month
order by
    am.user_id
  , am.month
