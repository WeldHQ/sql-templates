-- core_amazon_ads__campaign_report
-- Campaign Report. Extracts a comprehensive report of advertising performance for
-- Amazon's Sponsored Products, grouped by campaigns and accounts. This report
-- integrates data from the campaign report with the account and campaign tables to
-- provide metrics such as cost, clicks, and impressions for each campaign.
--
-- Grain: day x profile x campaign. Reads the version 3 sponsored products campaign
-- report, which can hold more than one row per campaign and day (one per
-- applicable budget rule); the metrics are summed over them.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Amazon Ads; check the output against the source before
-- relying on it.

with stats as (
select *
from {{ source('amazon_ads', 'sponsored_product_campaign_report_v3') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), campaign as (
select *
from {{ source('amazon_ads', 'sponsored_product_campaign') }}
), fields as (
select
cast(stats.date as date) as date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
stats.profile_id,
coalesce(campaign.name, stats.campaign_name) as campaign_name,
stats.campaign_id,
sum(stats.cost) as cost,
sum(stats.clicks) as clicks,
sum(stats.impressions) as impressions
from stats
left join campaign
on campaign.campaign_id = stats.campaign_id
and campaign.profile_id = stats.profile_id
left join account_info
on account_info.profile_id = stats.profile_id
group by 1,2,3,4,5,6,7
)
select *
from fields
