-- stg_tiktok_ads__ad_report
-- Ad Report. Generates an ad report by joining multiple tables from the TikTok Ads
-- integration. It retrieves data such as impressions, clicks, spend, reach,
-- conversions, likes, comments, shares, and various video metrics for each ad
-- group. The report also includes information about the advertiser, campaign,
-- account, currency, gender, audience type, and budget.
--
-- From the weld.app template library. Not reconciled against TikTok Ads;
-- check the output against the source before relying on it.

with
    daily as (
        select
            *
        from
            {{ source('tiktok_ads', 'ad_daily_report') }} --   to join another tiktok ads account
            --   union all
            --   select * from <second_account_table>
    )
  , ads as (
        select
            *
        from
            {{ source('tiktok_ads', 'ad') }}
    )
  , ad_groups as (
        select
            *
        from
            {{ source('tiktok_ads', 'ad_group') }}
    )
  , advertiser as (
        select
            *
        from
            {{ source('tiktok_ads', 'advertiser') }}
    )
  , campaigns as (
        select
            *
        from
            {{ source('tiktok_ads', 'campaign') }}
    )
select
    date_trunc(cast(cast(stat_time_day as timestamp) as date), day) date_day
  , ad_groups.advertiser_id account_id
  , advertiser.name account_name
  , campaigns.id campaign_id
  , campaigns.campaign_name
  , ad_groups.id ad_group_id
  , ad_groups.adgroup_name ad_group_name
  , daily.ad_id
  , ads.ad_name
  , advertiser.currency
  , ad_groups.gender
  , ad_groups.audience_type
  , ad_groups.budget
  , daily.impressions as impressions
  , daily.clicks as clicks
  , daily.spend as spend
  , daily.reach as reach
  , daily.conversion as conversion
  , daily.total_purchase_value as conversion_value
  , daily.likes as likes
  , daily.comments as comments
  , daily.shares as shares
  , daily.profile_visits as profile_visits
  , daily.follows as follows
  , daily.video_watched_2s as video_watched_2_s
  , daily.video_watched_6s as video_watched_6_s
  , daily.video_views_p25 as video_views_p_25
  , daily.video_views_p50 as video_views_p_50
  , daily.video_views_p75 as video_views_p_75
from
    daily
    left join ads on daily.ad_id = ads.id
    left join ad_groups on ads.ad_group_id = ad_groups.id
    left join advertiser on ads.advertiser_id = advertiser.id
    left join campaigns on ads.campaign_id = campaigns.id
