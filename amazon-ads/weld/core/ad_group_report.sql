-- core.amazon_ads.ad_group_report
-- Ad Group Report. This template extracts a comprehensive breakdown of advertising
-- performance on Amazon, grouped by ad groups for sponsored products. It integrates
-- data from the sponsored product ad group report with the profile and ad group
-- tables to deliver metrics like cost, clicks, and impressions for each ad group.
--
-- From the weld.app template library. Not reconciled against Amazon Ads;
-- check the output against the source before relying on it.

with report as (
select *
from {{raw.amazon_ads.sponsored_product_ad_group_report}}
), account_info as (
select *
from {{raw.amazon_ads.profile}}
), ad_group as (
select *
from {{raw.amazon_ads.sponsored_product_ad_group}}
), fields as (
select
report.date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
account_info.profile_id,
ad_group.name as ad_group_name,
report.campaign_id,
sum(report.cost) as cost,
sum(report.clicks) as clicks,
sum(report.impressions) as impressions
from report
left join ad_group
on ad_group.ad_group_id = report.ad_group_id
left join account_info
on account_info.profile_id = ad_group.profile_id
group by 1,2,3,4,5,6,7
)
select *
from fields
