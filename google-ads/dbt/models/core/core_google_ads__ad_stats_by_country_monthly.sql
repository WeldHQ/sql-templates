-- core_google_ads__ad_stats_by_country_monthly
-- Ad stats by country monthly. Generates monthly ad statistics by country,
-- including spend, clicks, CPC, cost per conversion, CTR, conversions, conversion
-- value, impressions, and interactions, using data from Google Ads. It groups the
-- data by month and country criterion ID.
--
-- Grain: month x country criterion ID. country_criterion_id is Google's
-- geo target ID (2208 is Denmark, 2840 the United States); join Google's geo
-- target list to name it. Spend is in the account currency, converted from
-- micros; with several accounts in different currencies, filter to one first.
-- Rates are worked out from the month's totals; ctr is a fraction.
--
-- From the weld.app template library, corrected. Not reconciled against Google
-- Ads; check the output against the source before relying on it.

select
    date_trunc(cast(date as date), month) as month
  , country_criterion_id
  , sum(cost_micros) / 1e6 as spend
  , sum(clicks) as clicks
  , safe_divide(sum(cost_micros) / 1e6, sum(clicks)) as cpc
  , safe_divide(sum(cost_micros) / 1e6, sum(conversions)) as cost_per_conversion
  , safe_divide(sum(clicks), sum(impressions)) as ctr
  , sum(conversions) as conversions
  , sum(conversions_value) as conversions_value
  , sum(impressions) as impressions
  , sum(interactions) as interactions
from
    {{ source('google_ads', 'ad_group_country_stats') }}
group by
    1
  , 2
