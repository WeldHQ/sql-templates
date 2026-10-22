-- core.google_ads.url_report
-- URL Report. Generates a report for URL performance in Google Ads. It retrieves
-- data from various tables, including ad stats, accounts, campaigns, ad groups, and
-- ads. The template calculates metrics such as spend, impressions, clicks, CPC,
-- CTR, CPM, and conversions. Additional columns can be specified manually if
-- needed.
--
-- From the weld.app template library. Not reconciled against Google Ads;
-- check the output against the source before relying on it.

with
    stats as (
        select
            *
        from
            {{raw.google_ads.ad_stats}} 
            -- to join another google ads account
            --   union all
            --   select * from <second_account_table>
    )
  , accounts as (
        select
            *
        from
            {{raw.google_ads.account}}
    )
  , campaigns as (
        select
            *
        from
            {{raw.google_ads.campaign}}
    )
  , ad_groups as (
        select
            *
        from
            {{raw.google_ads.ad_group}}
    )
  , ads as (
        select
            *
        from
            {{raw.google_ads.ad}}
    )

        select
            date_trunc(cast(date as date), day) date_day
          , accounts.id account_id
          , campaigns.name campaign_name
          , campaigns.id campaign_id
          , ad_groups.name ad_group_name
          , ad_groups.id ad_group_id
          , ads.id ad_id
          , ads.display_url
          , ads.final_urls
          , ads.final_url_suffix
      , coalesce(
            regexp_extract(ads.final_url_suffix, r'[?&]utm_source=([^&]*)')
          , 'google'
        ) as utm_source
      , coalesce(
            regexp_extract(ads.final_url_suffix, r'[?&]utm_medium=([^&]*)')
          , 'cpc'
        ) as utm_medium
      , coalesce(
            regexp_extract(ads.final_url_suffix, r'[?&]utm_campaign=([^&]*)')
          , campaigns.name
        ) as utm_campaign
      , coalesce(
            regexp_extract(ads.final_url_suffix, r'[?&]utm_content=([^&]*)')
          , ad_groups.name
        ) as utm_content
          , sum(cost_micros * 0.000001) as spend
          , sum(impressions) as impressions
          , sum(clicks) as clicks
          , sum(safe_divide((cost_micros * 0.000001), clicks)) as cpc
          , sum(safe_divide(clicks, impressions)) as ctr
          , sum(safe_divide((cost_micros * 0.000001), impressions)) * 1000 as cpm
          , sum(conversions) as conversions 
          -- Additional columns should be manually specified if needed
        from
            stats
            left join ads on stats.ad_id = ads.id
            and stats.ad_group_id = ads.ad_group_id
            left join ad_groups on ads.ad_group_id = ad_groups.id
            left join campaigns on ad_groups.campaign_id = campaigns.id
            left join accounts on campaigns.account_id = accounts.id
        where
            ads.final_urls is not null
        group by
            1
          , 2
          , 3
          , 4
          , 5
          , 6
          , 7
          , 8
          , 9
          , 10
          , 11
          , 12
          , 13
          , 14 
          -- Adjust these numbers according to the selected columns
