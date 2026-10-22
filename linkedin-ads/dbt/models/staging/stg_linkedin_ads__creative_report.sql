-- stg_linkedin_ads__creative_report
-- Creative Report. Generate a report on LinkedIn Ads performance. It combines data
-- from various tables such as creative, campaign, campaign_group, account, and
-- report to provide insights on metrics like spend, impressions, clicks, CPC, CTR,
-- and conversions. The template uses left joins to connect the tables based on
-- their respective IDs and groups the data by specific columns for aggregation.
--
-- From the weld.app template library. Not reconciled against LinkedIn Ads;
-- check the output against the source before relying on it.

with
    creative as (
        select
            *
        from
            {{ source('linkedin_ads', 'creative') }} --   to join another linkedin ads account
            --   union all
            --   select * from <second_account_table>
    )
  , campaign as (
        select
            *
        from
            {{ source('linkedin_ads', 'campaign') }}
    )
  , campaign_group as (
        select
            *
        from
            {{ source('linkedin_ads', 'campaign_group') }}
    )
  , account as (
        select
            *
        from
            {{ source('linkedin_ads', 'account') }}
    )
  , report as (
        select
            *
        from
            {{ source('linkedin_ads', 'ad_analytics_by_creative') }}
    )
select
    cast(report.date as date) date_day
  , cast(account.id as string) account_id
  , account.name account_name
  , creative.id creative_id
  , campaign.id campaign_id
  , campaign.name campaign_name
  , campaign_group.id campaign_group_id
  , campaign_group.name campaign_group_name
  , campaign.status as campaign_status
  , campaign_group.status as campaign_group_status
  , account.currency
  , creative.last_modified_at
  , creative.created_at
  , sum(cost_in_local_currency) spend
  , sum(impressions) impressions
  , sum(clicks) as clicks
  , sum(safe_divide(cost_in_local_currency, clicks)) as cpc
  , sum(safe_divide(clicks, impressions)) as ctr
  , sum(safe_divide(cost_in_local_currency, impressions)) * 1000 as cpm
  , sum(external_website_conversions) as conversions -- Additional  columns should be manually specified if needed
from
    report
    left join creative on report.creative_id = creative.id
    left join campaign on creative.campaign_id = campaign.id
    left join campaign_group on campaign.campaign_group_id = campaign_group.id
    left join account on campaign.account_id = account.id
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
  , 13 -- Adjust these numbers according to the selected columns
