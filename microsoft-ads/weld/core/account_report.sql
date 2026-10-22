-- core.microsoft_ads.account_report
-- Account Report. Generates an account report by integrating with Microsoft Ads. It
-- retrieves data from the ad_performance_daily_report and account tables, joins
-- them based on the account_id, and calculates metrics such as clicks, impressions,
-- and spend. The resulting report includes information about the date, account
-- name, account ID, time zone, device OS, device type, network, and currency code.
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
  , accounts as (
        select
            *
        from
            {{raw.microsoft_ads.account}}
    )
  , joined as (
        select
            report.date as date_day
          , accounts.name account_name
          , accounts.id account_id
          , accounts.time_zone as account_timezone
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
        group by
            1
          , 2
          , 3
          , 4
          , 5
          , 6
          , 7
          , 8 -- Adjust these numbers according to the selected columns
    )
select
    *
from
    joined
