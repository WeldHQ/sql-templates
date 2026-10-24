-- core_amazon_ads__ad_group_report
-- Ad Group Report. This template extracts a comprehensive breakdown of advertising
-- performance on Amazon, grouped by ad groups for sponsored products. It integrates
-- data from the sponsored product ad group report with the profile and ad group
-- tables to deliver metrics like cost, clicks, and impressions for each ad group.
--
-- Grain: day x profile x campaign x ad group. Reads the version 3 sponsored
-- products ad group report.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Amazon Ads; check the output against the source before
-- relying on it.

with stats as (
select *
from {{ source('amazon_ads', 'sponsored_product_ad_group_report_v3') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), ad_group as (
select *
from {{ source('amazon_ads', 'sponsored_product_ad_group_v3') }}
), fields as (
select
cast(stats.date as date) as date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
stats.profile_id,
coalesce(ad_group.name, stats.ad_group_name) as ad_group_name,
stats.campaign_id,
stats.ad_group_id,
sum(stats.cost) as cost,
sum(stats.clicks) as clicks,
sum(stats.impressions) as impressions
from stats
left join ad_group
on ad_group.ad_group_id = stats.ad_group_id
and ad_group.profile_id = stats.profile_id
left join account_info
on account_info.profile_id = stats.profile_id
group by 1,2,3,4,5,6,7,8
)
select *
from fields
