-- stg_google_ads__ad_report
-- Ad Report. Generates an ad report by joining data from various tables in the
-- Google Ads integration. It retrieves information such as date, account ID and
-- name, campaign name and ID, ad group name and ID, ad ID and name, ad status and
-- type, display URL, final URLs, spend, impressions, clicks, CPC, CTR, CPM, and
-- conversions. Additional columns can be manually specified if needed.
--
-- From the weld.app template library. Not reconciled against Google Ads;
-- check the output against the source before relying on it.

select
    date_trunc(cast(date as date), day) date_day
  , cast(account_id as string) account_id
  , account_descriptive_name as account_name
  , campaign_name campaign_name
  , cast(campaign_id as string) campaign_id
  , ad_group_name ad_group_name
  , cast(ad_group_id as string) ad_group_id
  , cast(ad_id as string) ad_id
  , ad_name ad_name
  , ad_network_type ad_type
  , cost_micros * 0.000001 as spend
  , clicks
  , impressions
  , interactions
  , conversions 
  , conversions_value
  , safe_divide(conversions_value, cost_micros * 0.000001) as roas -- conversion value per unit of spend
from
  {{ source('google_ads', 'ad_stats') }} stats
