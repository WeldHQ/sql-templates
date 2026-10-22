-- staging.pinterest_ads.ad_report
-- Ad Report. Generates an ad report for the Pinterest Ads integration. It retrieves
-- data from multiple tables, including ad reports, ad accounts, campaigns, and ads.
-- The report includes information such as date, account name and ID, campaign name
-- and ID, ad name, status, type, created time, spend, impressions, clicks, CPC,
-- CTR, CPM, and total conversions. The data is grouped by various columns for
-- analysis.
--
-- From the weld.app template library. Not reconciled against Pinterest Ads;
-- check the output against the source before relying on it.

with
    report as (
        select
            *
        from
            {{raw.pinterest_ads.ad_report}} --   to join another pinterest ads account
            --   union all
            --   select * from <second_account_table>
    )
  , advertisers as (
        select
            *
        from
            {{raw.pinterest_ads.ad_account}}
    )
  , ad as (
        select
            *
        from
            {{raw.pinterest_ads.ad}}
    )
select
    cast(report.date as date) date_day
  , advertisers.name account_name
  , advertisers.id account_id
  , '' as campaign_name
  , ad.campaign_id campaign_id
  , ad.name ad_name
  , report.ad_id
  , ad.status as ad_status
  , ad.type as ad_type
  , ad.created_time
  , report.spend_in_micro_dollar / 1000000 spend
  , case
        when report.impression_1_gross is null then report.impression_2
        else report.impression_1_gross
    end as impressions
  , total_engagement as clicks
  , total_conversions conversions
from
    report
    left join ad on report.ad_group_id = ad.id
    left join advertisers on ad.ad_account_id = advertisers.id
