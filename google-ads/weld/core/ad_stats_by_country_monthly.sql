-- core.google_ads.ad_stats_by_country_monthly
-- Ad stats by country monthly. Generates monthly ad statistics by country,
-- including spend, clicks, CPC, cost per conversion, CTR, conversions, conversion
-- value, impressions, and interactions, using data from Google Ads. It groups the
-- data by month and country criterion ID.
--
-- From the weld.app template library. Not reconciled against Google Ads;
-- check the output against the source before relying on it.

select
date_trunc(cast(date as date), month) month
, country_criterion_id
, sum(cost_micros * 0.000001) as spend
, sum(clicks) as clicks
, avg(safe_divide((cost_micros * 0.000001), clicks)) as cpc
, sum(safe_divide((cost_micros * 0.000001), conversions)) as cost_per_conversion
, sum(safe_divide(clicks, impressions)) as ctr
, sum(conversions) conversions
, sum (conversions_value) conversions_value
, sum(impressions) as impressions
, sum(interactions) as interactions
from
{{raw.google_ads.ad_group_country_stats}}
group by
1
, 2
, 3
