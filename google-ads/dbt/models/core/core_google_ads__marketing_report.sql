-- core_google_ads__marketing_report
-- Marketing Insights Dashboard. This SQL template consolidates advertising data
-- from multiple platforms, including Facebook, Google, LinkedIn, TikTok, Snapchat,
-- and Pinterest, into a unified dataset. It aggregates metrics such as clicks,
-- impressions, spend, and conversions, and calculates performance indicators like
-- CTR, CPC, CPM, and conversion rate. The result is grouped by date, platform,
-- account, campaign, and ad identifiers for comprehensive marketing insights.
--
-- Grain: day x platform x account x campaign x ad. Spend and conversion value
-- are in each account's own currency; nothing is converted, so totals across
-- platforms only add up when the accounts share a currency. ctr and
-- conversion_rate are percentages; all rates are worked out from totals.
-- LinkedIn campaign groups fill the campaign columns and LinkedIn creatives the
-- ad columns. Snapchat rows have no campaign.
--
-- Only the Google Ads block is active. Each other platform reads that platform's
-- staging ad report (google-ads/, facebook-ads/, linkedin-ads/, tiktok-ads/,
-- snapchat-ads/, pinterest-ads/ in this repo). Deploy the ones you use, then
-- remove the comment markers around their blocks; delete the rest.
--
-- From the weld.app template library, corrected. Not reconciled against the ad
-- platforms; check the output against each source before relying on it.

with
    all_data as (
        select
            date_day,
            'google' as platform,
            cast(account_id as string) as account_id,
            account_name,
            cast(campaign_id as string) as campaign_id,
            campaign_name,
            cast(ad_id as string) as ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            conversions_value as conversion_value
        from
            {{ ref('stg_google_ads__ad_report') }}

        /*
        union all

        select
            date_day,
            'facebook' as platform,
            cast(account_id as string) as account_id,
            account_name,
            cast(campaign_id as string) as campaign_id,
            campaign_name,
            cast(ad_id as string) as ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            purchase as conversions,
            conversion_value
        from
            {{ ref('stg_facebook_ads__ad_report') }}

        union all

        select
            date_day,
            'linkedin' as platform,
            cast(account_id as string) as account_id,
            account_name,
            cast(campaign_group_id as string) as campaign_id,
            campaign_group_name as campaign_name,
            cast(creative_id as string) as ad_id,
            creative_name as ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            conversion_value
        from
            {{ ref('stg_linkedin_ads__creative_report') }}

        union all

        select
            date_day,
            'tiktok' as platform,
            cast(account_id as string) as account_id,
            account_name,
            cast(campaign_id as string) as campaign_id,
            campaign_name,
            cast(ad_id as string) as ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversion as conversions,
            conversion_value
        from
            {{ ref('stg_tiktok_ads__ad_report') }}

        union all

        select
            date_day,
            'snapchat' as platform,
            cast(account_id as string) as account_id,
            account_name,
            -- the Snapchat ad report has no campaign columns
            cast(null as string) as campaign_id,
            cast(null as string) as campaign_name,
            cast(ad_id as string) as ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            conversion_value
        from
            {{ ref('stg_snapchat_ads__ad_report') }}

        union all

        select
            date_day,
            'pinterest' as platform,
            cast(account_id as string) as account_id,
            account_name,
            cast(campaign_id as string) as campaign_id,
            campaign_name,
            cast(ad_id as string) as ad_id,
            ad_name,
            clicks,
            impressions,
            spend,
            conversions,
            cast(null as float64) as conversion_value
        from
            {{ ref('stg_pinterest_ads__ad_report') }}
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
