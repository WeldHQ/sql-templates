-- core_microsoft_ads__campaign_report
-- Campaign Report. Generates a campaign report by integrating with Microsoft Ads.
-- It combines data from the campaign performance daily report, campaign, and
-- account tables. The joined table includes information such as date, account name
-- and ID, campaign name and ID, campaign type and status, device OS and type,
-- network, currency code, clicks, impressions, and spend.
--
-- From the weld.app template library. Not reconciled against Microsoft Ads;
-- check the output against the source before relying on it.

with
    report as (
        select
            *
        from
            {{ source('microsoft_ads', 'campaign_performance_daily_report') }}
    )
  , campaigns as (
        select
            *
        from
            {{ source('microsoft_ads', 'campaign') }}
    )
  , accounts as (
        select
            *
        from
            {{ source('microsoft_ads', 'account') }}
    )
  , joined as (
        select
            report.date date_day
          , accounts.name account_name
          , accounts.id account_id
          , campaigns.campaign campaign_name
          , campaigns.id campaign_id
          , campaigns.campaign_type
          , campaigns.status as campaign_status
          , report.device_os
          , report.device_type
          , report.network
          , report.currency_code
          , sum(report.clicks) as clicks
          , sum(report.impressions) as impressions
          , sum(report.spend) as spend -- Additional pass-through columns should be manually specified if needed
        from
            report
            left join accounts on report.account_id = accounts.id
            left join campaigns on report.campaign_id = campaigns.id
        group by
            1
          , 2
          , 3
          , 4
          , 5
          , 6
          , 7
          , 8
          , 9
          , 10
          , 11 -- Adjust these numbers according to the selected columns
    )
select
    *
from
    joined
