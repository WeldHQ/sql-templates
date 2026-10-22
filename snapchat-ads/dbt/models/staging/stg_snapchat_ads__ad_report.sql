-- stg_snapchat_ads__ad_report
-- Ad Report. Generates an ad report by integrating with Snapchat Ads. It retrieves
-- data from various tables such as ad_daily_report, campaign, ad_account, and ad.
-- The report includes information such as date, account ID and name, campaign ID
-- and name, ad ID and name, currency, spend, impressions, clicks, CPC, CTR, CPM,
-- and conversions. The data is filtered based on the date and grouped by different
-- columns.
--
-- From the weld.app template library. Not reconciled against Snapchat Ads;
-- check the output against the source before relying on it.

with
    report as (
        select
            *
        from
            {{ source('snapchat_ads', 'ad_daily_report') }}
    
    )
  , account as (
        select
            *
        from
            {{ source('snapchat_ads', 'ad_account') }}
    )
  , ads as (
        select
            *
        from
            {{ source('snapchat_ads', 'ad') }}
    )
    , creative as (  
        select
            *
        from
            {{ source('snapchat_ads', 'creative') }})

    
select
    cast(report.date as date) as date_day
  , account.ad_account_id as account_id
  , account.name as account_name
  , report.ad_id
  , ads.name ad_name
  , creative.name as creative_name
  , creative.id as creative_id
  , account.currency
  , safe_divide(spend, 1000000) spend
  , report.impressions as impressions
  , report.swipes as clicks
  , conversion_purchases as conversions
  , conversion_purchases_value as conversion_value
from
    report
    left join ads on report.ad_id = ads.id
    left join account on ads.ad_account_id = account.id
    left join creative on creative.id = ads.creative_id
where
    cast(report.date as date) <= current_date()
