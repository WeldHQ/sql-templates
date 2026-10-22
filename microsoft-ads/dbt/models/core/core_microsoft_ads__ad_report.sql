-- core_microsoft_ads__ad_report
-- Ad Report. Generates an ad report by joining data from multiple tables related to
-- Microsoft Ads. It retrieves information such as date, account name and ID,
-- campaign name and ID, ad group name and ID, ad name and ID, device OS, device
-- type, network, currency code, clicks, impressions, and spend. The template
-- performs a left join on the specified tables and groups the data based on
-- selected columns. The final result includes all columns from the joined data.
--
-- From the weld.app template library. Not reconciled against Microsoft Ads;
-- check the output against the source before relying on it.

with
    report as (
        select
            *
        from
            {{ source('microsoft_ads', 'ad_performance_daily_report') }}
    )
  , ads as (
        select
            *
        from
            {{ source('microsoft_ads', 'ad') }} 
    )
  , ad_groups as (
        select
            *
        from
            {{ source('microsoft_ads', 'ad_group') }}
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
          , ad_groups.ad_group ad_group_name
          , ad_groups.id ad_group_id
          , ads.title ad_name
          , ads.title ad_name
          , ads.id ad_id
          , report.device_os
          , report.device_type
          , report.network
          , report.currency_code
          , sum(report.clicks) as clicks
          , sum(report.impressions) as impressions
          , sum(report.spend) as spend 
          -- Additional pass-through columns should be manually specified if needed
        from
            report
            left join ads on report.ad_id = ads.id
            left join ad_groups on report.ad_group_id = ad_groups.id
            left join campaigns on report.campaign_id = campaigns.id
            left join accounts on report.account_id = accounts.id
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
          , 11
          , 12
          , 13
          , 14  -- Adjust these numbers according to the selected columns
    )
select
    *
from
    joined
