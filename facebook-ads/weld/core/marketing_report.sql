-- core.facebook_ads.marketing_report
-- Marketing Insights Dashboard. This SQL template consolidates advertising data
-- from multiple platforms, including Facebook, Google, LinkedIn, TikTok, Snapchat,
-- and Pinterest, into a unified dataset. It aggregates metrics such as clicks,
-- impressions, spend, and conversions, and calculates performance indicators like
-- CTR, CPC, CPM, and conversion rate. The result is grouped by date, platform,
-- account, campaign, and ad identifiers for comprehensive marketing insights.
--
-- From the weld.app template library. Not reconciled against Facebook Ads;
-- check the output against the source before relying on it.

-- Facebook staging report can be created using the template: facebook ad reports
-- Google staging report can be created using the template: google ad reports
-- LinkedIn staging report can be created using the template: linkedin ad reports
-- TikTok staging report can be created using the template: tiktok ad reports
-- Snapchat staging report can be created using the template: snapchat ad reports
-- Pinterest staging report can be created using the template: pinterest ad reports
-- Note: If certain platforms are not used, you can remove their respective sections from the UNION ALL queries below.

with
    all_data as (
        select
            date_day,
            'facebook' as platform,
            account_id,
            account_name,
            campaign_id,
            campaign_name,
            ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            purchase as conversions,
            conversion_value
        from
            {{staging.facebook_ads.ad_report}}
        
      /*  union all

        select
            date_day,
            'google' as platform,
            account_id,
            account_name,
            campaign_id,
            campaign_name,
            ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            conversions_value as conversion_value
        from
            {{staging.google_ads.ad_report}}
        
        union all

        select
            date_day,
            'linkedin' as platform,
            account_id,
            account_name,
            campaign_group_id as campaign_id,
            campaign_group_name as campaign_name,
            creative_id as ad_id,
            creative_name as ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            conversion_value
        from
            {{staging.linkedin_ads.creative_report}}
        
        union all

        select
            date_day,
            'tiktok' as platform,
            account_id,
            account_name,
            campaign_id,
            campaign_name,
            ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversion as conversions,
            conversion_value
        from
            {{staging.tiktok_ads.ad_report}}
        
        union all

        select
            date_day,
            'snapchat' as platform,
            account_id,
            account_name,
            creative_id as campaign_id,
            campaign_id as campaign_name,
            ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            conversion_value
        from
            {{staging.snapchat_ads.ad_report}}
        
        union all

        select
            date_day,
            'pinterest' as platform,
            account_id,
            account_name,
            campaign_id,
            campaign_name,
            ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            null as conversion_value
        from
            {{staging.pinterest_ads.ad_report}}
            
            */
    )
select
    date_day,
    platform,
    account_id,
    account_name,
    campaign_id,
    campaign_name,
    ad_id,
    ad_name,
    sum(clicks) as clicks,
    sum(impressions) as impressions,
    sum(spend) as spend,
    sum(conversions) as conversions,
    sum(conversion_value) as conversion_value,
    safe_divide(sum(clicks), sum(impressions)) * 100 as ctr,
    safe_divide(sum(spend), sum(clicks)) as cpc,
    safe_divide(sum(spend), sum(impressions)) * 1000 as cpm,
    safe_divide(sum(conversions), sum(clicks)) * 100 as conversion_rate
from
    all_data
group by
    date_day,
    platform,
    account_id,
    account_name,
    campaign_id,
    campaign_name,
    ad_id,
    ad_name
