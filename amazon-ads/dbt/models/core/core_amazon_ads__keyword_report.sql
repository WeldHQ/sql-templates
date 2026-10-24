-- core_amazon_ads__keyword_report
-- Keyword Report. This template extracts a comprehensive breakdown of advertising
-- performance on Amazon, grouped by keywords for sponsored products. It integrates
-- data from the sponsored product keyword report with the profile and keyword
-- tables to deliver metrics like cost, clicks, and impressions for each keyword.
--
-- Grain: day x profile x campaign x keyword. Reads the version 3 sponsored products
-- keyword report, which holds the broad, phrase and exact match keywords.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Amazon Ads; check the output against the source before
-- relying on it.

with stats as (
select *
from {{ source('amazon_ads', 'sponsored_product_keyword_report_v3') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), keyword as (
select *
from {{ source('amazon_ads', 'sponsored_product_keyword') }}
), fields as (
select
cast(stats.date as date) as date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
stats.profile_id,
coalesce(keyword.keyword_text, stats.keyword) as keyword_text,
stats.campaign_id,
stats.keyword_id,
sum(stats.cost) as cost,
sum(stats.clicks) as clicks,
sum(stats.impressions) as impressions
from stats
left join keyword
on keyword.keyword_id = stats.keyword_id
and keyword.profile_id = stats.profile_id
left join account_info
on account_info.profile_id = stats.profile_id
group by 1,2,3,4,5,6,7,8
)
select *
from fields
