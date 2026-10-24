-- core_linkedin_pages__page_performance_daily
-- The Updates (content) section of LinkedIn Page analytics: organic impressions,
-- reach and engagement across all of a Page's posts, per day.
--
-- Grain: date_day x organization_id. Days are UTC.
-- Depends on: staging.linkedin_pages.share_statistics_daily
--
-- Organic only. Sponsored impressions and clicks are in LinkedIn Ads, not here.
-- unique_impressions is unique members per day: summing days overcounts people
-- who saw posts on several days, so there is no monthly reach to build from it.
--
-- engagement_rate is LinkedIn's own figure for the day. To roll up to a week or
-- month, divide the summed `engagements` by the summed `impressions`; averaging
-- the daily rate weights a quiet day like a busy one.

SELECT
    date_day,
    organization_id,
    organization_name,
    impressions,
    unique_impressions,
    clicks,
    likes,
    comments,
    shares,
    clicks + likes + comments + shares                                  AS engagements,
    engagement_rate,
    SAFE_DIVIDE(clicks + likes + comments + shares, impressions)        AS engagement_rate_calculated,
    SAFE_DIVIDE(clicks, impressions)                                    AS click_through_rate
FROM {{ ref('stg_linkedin_pages__share_statistics_daily') }}
