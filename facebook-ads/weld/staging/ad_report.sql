-- staging.facebook_ads.ad_report
-- Ad Report. Integrates with Facebook Ads and retrieves data from various tables
-- such as ad_insight, account, campaign, ad_set, and ad. It selects specific
-- columns from these tables and performs calculations to generate aggregated
-- metrics such as spend, reach, impressions, clicks, CPC, CTR, and CPM. The
-- template then joins these tables based on specific conditions and groups the
-- results by certain columns.
--
-- From the weld.app template library, corrected. Not reconciled against
-- Facebook Ads; check the output against the source before relying on it.

with
    stats as (
        select
            *
        from
            {{raw.facebook_ads.ad_insight}}
    )
  , ad as (
        select
            *
        from
            {{raw.facebook_ads.ad}}
    )
  , creative as (
        select
            *
        from
            {{raw.facebook_ads.creative}}
    )
  , action_data as (
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
            {{raw.facebook_ads.ad_roas_insight_conversion_insights}}
        order by
            date desc
    )
  , action_value as (
        -- one row per ad and day: the action values table has a row per action
        -- type, so it is summed here before the join
        select
             date
          , ad_id
          , sum(
                case
                    when action_type = 'purchase' then value
                end
            ) as conversion_value
        from
            {{raw.facebook_ads.ad_roas_insight_action_values}}
        group by
            date
          , ad_id
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
  , ad.status
  , creative.title as creative_title
  , spend
  , reach
  , impressions
  , clicks
  , inline_link_clicks
  , ctr
  , cpm
  , cpc
  , action_data.*
except
(ad_id, date)
,   action_value.conversion_value
from
    stats
    left join action_data on action_data.ad_id = stats.ad_id
    and cast(action_data.date as date) = cast(stats.date as date)
    left join action_value on action_value.ad_id = stats.ad_id
    and cast(action_value.date as date) = cast(stats.date as date)
    left join ad on stats.ad_id = ad.id
    left join creative on creative.id = ad.creative_id
order by
    1 desc
