-- core_amazon_ads__campaign_report
-- Campaign Report. Extracts a comprehensive report of advertising performance for
-- Amazon's Sponsored Products, grouped by campaigns and accounts. This report
-- integrates data from the campaign report with the account and campaign tables to
-- provide metrics such as cost, clicks, and impressions for each campaign.
--
-- From the weld.app template library. Not reconciled against Amazon Ads;
-- check the output against the source before relying on it.

with report as (
select *
from {{ source('amazon_ads', 'sponsored_product_campaign_report') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), campaigns as (
select *
from{{ source('amazon_ads', 'sponsored_product_campaign') }}
), fields as (
select
report.date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
account_info.profile_id,
campaigns.name as campaign_name,
report.campaign_id,
sum(report.cost) as cost,
sum(report.clicks) as clicks,
sum(report.impressions) as impressions
from report
left join campaigns
on campaigns.campaign_id = report.campaign_id
left join account_info
on account_info.profile_id = campaigns.profile_id
group by 1,2,3,4,5,6,7
)
select *
from fields
