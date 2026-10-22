-- core.microsoft_ads.ad_group_report
-- Ad Group Report. Generates a report that combines data from the
-- "ad_performance_daily_report," "ad_group," "campaign," and "account" tables in
-- the Microsoft Ads integration. It joins these tables based on specific columns
-- and calculates aggregated metrics such as clicks, impressions, and spend. The
-- resulting report includes information on the date, account, campaign, ad group,
-- device, network, and currency code.
--
-- From the weld.app template library. Not reconciled against Microsoft Ads;
-- check the output against the source before relying on it.

with
    report as (
        select
            *
        from
            {{raw.microsoft_ads.ad_performance_daily_report}}
    )
  , ad_groups as (
        select
            *
        from
            {{raw.microsoft_ads.ad_group}}
    )
  , campaigns as (
        select
            *
        from
            {{raw.microsoft_ads.campaign}}
    )
  , accounts as (
        select
            *
        from
            {{raw.microsoft_ads.account}}
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
            left join ad_groups on report.ad_group_id = ad_groups.id
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
