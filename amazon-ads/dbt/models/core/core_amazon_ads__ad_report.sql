-- core_amazon_ads__ad_report
-- Ad Report. This template extracts a comprehensive breakdown of advertising
-- performance on Amazon, grouped by product ads for sponsored products. It
-- integrates data from the sponsored product product ad report with the profile and
-- ad tables to deliver metrics like cost, clicks, and impressions for each product
-- ad.
--
-- Grain: day x profile x campaign x product ad. Reads the version 3 sponsored
-- products advertised product report, which splits a product ad by advertised
-- ASIN; the metrics are summed over them.
--
-- From the weld.app template library, corrected and ported to the current synced
-- schema. Not reconciled against Amazon Ads; check the output against the source
-- before relying on it.

with stats as (
select *
from {{ source('amazon_ads', 'sponsored_product_product_ad_report_v3') }}
), account_info as (
select *
from {{ source('amazon_ads', 'profile') }}
), ad as (
select *
from {{ source('amazon_ads', 'sponsored_product_product_ad') }}
), fields as (
select
cast(stats.date as date) as date,
account_info.account_info_name,
account_info.account_info_id,
account_info.country_code,
stats.profile_id,
stats.campaign_id,
stats.ad_id,
coalesce(ad.asin, stats.advertised_asin) as asin,
sum(stats.cost) as cost,
sum(stats.clicks) as clicks,
sum(stats.impressions) as impressions
from stats
left join ad
on ad.ad_id = stats.ad_id
and ad.profile_id = stats.profile_id
left join account_info
on account_info.profile_id = stats.profile_id
group by 1,2,3,4,5,6,7,8
)
select *
from fields
