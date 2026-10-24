-- core_amazon_ads__ad_report
-- Ad Report. This template extracts a comprehensive breakdown of advertising
-- performance on Amazon, grouped by product ads for sponsored products. It
-- integrates data from the sponsored product product ad report with the profile and
-- ad tables to deliver metrics like cost, clicks, and impressions for each product
-- ad.
--
-- Grain: day x profile x campaign x product ad.
--
-- From the weld.app template library, corrected. Not reconciled against Amazon
-- Ads; check the output against the source before relying on it.

with report as (
select *
from {{ source('amazon_ads', 'sponsored_product_product_ad_report') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), ad as (
select *
from {{ source('amazon_ads', 'sponsored_product_product_ad') }}
), fields as (
select
report.date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
account_info.profile_id,
report.campaign_id,
report.ad_id,
sum(report.cost) as cost,
sum(report.clicks) as clicks,
sum(report.impressions) as impressions
from report
left join ad
on ad.ad_id = report.ad_id
left join account_info
on account_info.profile_id = ad.profile_id
group by 1,2,3,4,5,6,7
)
select *
from fields
