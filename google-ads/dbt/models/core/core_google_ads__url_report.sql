-- core_google_ads__url_report
-- Daily Google Ads delivery per ad, with the landing page it sends traffic to
-- and the UTM tags that page receives. Use it to tie ad spend to sessions in
-- your web analytics.
--
-- Grain: day x ad. Ads without final URLs (app and some video ads) are left
-- out. Spend is in the account currency (account_currency), converted from
-- micros. Rates are worked out from the day's totals: ctr is clicks /
-- impressions as a fraction, cpc is spend per click, cpm is spend per thousand
-- impressions.
--
-- UTM tags are read from the ad's final URL suffix. Where a tag is missing it
-- falls back to google / cpc / campaign name / ad group name, which is what
-- most auto-tagged setups report.
--
-- Depends on: raw.google_ads.ad_stats, ad, account
--
-- From the weld.app template library, rewritten and corrected. Not reconciled
-- against Google Ads; check the output against the source before relying on it.

WITH ad_days AS (
    -- ad_stats carries the campaign and ad group names as of the report, so no
    -- campaign or ad group lookup is needed.
    SELECT
        CAST(date AS DATE)                                  AS date_day,
        account_id,
        campaign_id,
        ANY_VALUE(campaign_name)                            AS campaign_name,
        ad_group_id,
        ANY_VALUE(ad_group_name)                            AS ad_group_name,
        ad_id,
        SUM(impressions)                                    AS impressions,
        SUM(clicks)                                         AS clicks,
        SUM(cost_micros) / 1e6                              AS spend,
        SUM(conversions)                                    AS conversions
    FROM {{ source('google_ads', 'ad_stats') }}
    GROUP BY date_day, account_id, campaign_id, ad_group_id, ad_id
),

landing_pages AS (
    -- An ad ID is only unique within its ad group, so both keys identify it.
    SELECT
        ad_group_id,
        id                                                  AS ad_id,
        final_urls,
        display_url,
        final_url_suffix
    FROM {{ source('google_ads', 'ad') }}
    WHERE final_urls IS NOT NULL
),

account_currency AS (
    SELECT id AS account_id, currency_code AS account_currency
    FROM {{ source('google_ads', 'account') }}
),

tagged AS (
    SELECT
        d.*,
        lp.final_urls,
        lp.display_url,
        lp.final_url_suffix,
        ac.account_currency,
        REGEXP_EXTRACT(lp.final_url_suffix, r'(?:^|[?&])utm_source=([^&]*)')   AS suffix_source,
        REGEXP_EXTRACT(lp.final_url_suffix, r'(?:^|[?&])utm_medium=([^&]*)')   AS suffix_medium,
        REGEXP_EXTRACT(lp.final_url_suffix, r'(?:^|[?&])utm_campaign=([^&]*)') AS suffix_campaign,
        REGEXP_EXTRACT(lp.final_url_suffix, r'(?:^|[?&])utm_content=([^&]*)')  AS suffix_content
    FROM ad_days d
    JOIN landing_pages lp
      ON lp.ad_group_id = d.ad_group_id
     AND lp.ad_id = d.ad_id
    LEFT JOIN account_currency ac
      ON ac.account_id = d.account_id
)

SELECT
    date_day,
    CAST(account_id AS STRING)                              AS account_id,
    account_currency,
    CAST(campaign_id AS STRING)                             AS campaign_id,
    campaign_name,
    CAST(ad_group_id AS STRING)                             AS ad_group_id,
    ad_group_name,
    CAST(ad_id AS STRING)                                   AS ad_id,
    final_urls,
    display_url,
    final_url_suffix,
    COALESCE(suffix_source, 'google')                       AS utm_source,
    COALESCE(suffix_medium, 'cpc')                          AS utm_medium,
    COALESCE(suffix_campaign, campaign_name)                AS utm_campaign,
    COALESCE(suffix_content, ad_group_name)                 AS utm_content,
    impressions,
    clicks,
    spend,
    conversions,
    SAFE_DIVIDE(clicks, impressions)                        AS ctr,
    SAFE_DIVIDE(spend, clicks)                              AS cpc,
    SAFE_DIVIDE(spend, impressions) * 1000                  AS cpm
FROM tagged
