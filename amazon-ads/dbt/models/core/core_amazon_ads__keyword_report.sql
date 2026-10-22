-- core_amazon_ads__keyword_report
-- Keyword Report. This template extracts a comprehensive breakdown of advertising
-- performance on Amazon, grouped by keywords for sponsored products. It integrates
-- data from the sponsored product keyword report with the profile and keyword
-- tables to deliver metrics like cost, clicks, and impressions for each keyword.
--
-- From the weld.app template library. Not reconciled against Amazon Ads;
-- check the output against the source before relying on it.

with report as (
select *
from {{ source('amazon_ads', 'sponsored_product_keyword_report') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), keyword as (
select *
from {{ source('amazon_ads', 'sponsored_product_keyword') }}
), fields as (
select
report.date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
account_info.profile_id,
keyword.keyword_text as keyword_text,
report.campaign_id,
sum(report.cost) as cost,
sum(report.clicks) as clicks,
sum(report.impressions) as impressions
from report
left join keyword
on keyword.keyword_id = report.keyword_id
left join account_info
on account_info.profile_id = keyword.profile_id
group by 1,2,3,4,5,6,7
)
select *
from fields
