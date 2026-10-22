-- core_facebook_ads__conversion_insights
-- Conversion Insights. This SQL template retrieves conversion insights data from
-- Facebook Ads, including various metrics such as spend, reach, impressions,
-- clicks, and more. It joins data from different tables like ad_insight, ad, and
-- ad_roas_insight_conversion_insights to provide a comprehensive analysis of ad
-- performance.
--
-- From the weld.app template library. Not reconciled against Facebook Ads;
-- check the output against the source before relying on it.

with
    stats as (
        select
            *
        from
            {{ source('facebook_ads', 'ad_insight') }}
    )
  , ad as (
        select
            *
        from
            {{ source('facebook_ads', 'ad') }}
    ),
    action_data as (
        select
            *
        except
        (
            account_id
          , account_name
          , account_currency
          , campaign_id
          , adset_id
        )
        from
            {{ source('facebook_ads', 'ad_roas_insight_conversion_insights') }}
    )
select
    cast(stats.date as date) date_day
  , stats.account_id account_id
  , stats.account_name account_name
  , stats.campaign_id campaign_id
  , stats.campaign_name campaign_name
  , stats.adset_id ad_set_id
  , stats.adset_name ad_set_name
  , stats.ad_id ad_id
  , stats.ad_name ad_name
  , bid_amount
  , bid_type
  , configured_domain
  , configured_status
  , created_time
  , effective_status
  , last_updated_by_app_id
  , status
  , updated_time
  , spend
  , reach
  , impressions
  , clicks
  , inline_link_clicks
  , ctr
  , cpm
  , cpc
  , action_data.* except (ad_id, date)

from
    stats
    left join ad on stats.ad_id = ad.id
    left join action_data on action_data.ad_id = stats.ad_id
    and cast(action_data.date as date) = cast(stats.date as date)
order by
    created_time desc
