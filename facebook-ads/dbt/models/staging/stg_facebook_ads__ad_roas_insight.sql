-- stg_facebook_ads__ad_roas_insight
-- Thin wrapper over raw `ad_roas_insight`, the connector's daily ad level
-- insights report that also carries purchase values. Casts, renames, de-duplicates.
-- Grain: ad account x campaign x ad set x ad x date (the report's own key).
--
-- spend is already in the ad account's currency (Meta does not use micros or
-- cents here). clicks is Meta's "Clicks (all)"; link_clicks is "Link clicks".

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(date AS DATE)                                       AS date_day,
        REGEXP_REPLACE(CAST(account_id AS STRING), r'^act_', '') AS account_id,
        CAST(account_name AS STRING)                             AS account_name,
        UPPER(CAST(account_currency AS STRING))                  AS currency,
        CAST(campaign_id AS STRING)                              AS campaign_id,
        CAST(campaign_name AS STRING)                            AS campaign_name,
        CAST(adset_id AS STRING)                                 AS ad_set_id,
        CAST(adset_name AS STRING)                               AS ad_set_name,
        CAST(ad_id AS STRING)                                    AS ad_id,
        CAST(ad_name AS STRING)                                  AS ad_name,
        COALESCE(CAST(spend AS FLOAT64), 0)                      AS spend,
        COALESCE(CAST(impressions AS INT64), 0)                  AS impressions,
        COALESCE(CAST(clicks AS INT64), 0)                       AS clicks_all,
        COALESCE(CAST(inline_link_clicks AS INT64), 0)           AS link_clicks,
        CAST(reach AS INT64)                                     AS reach,
        ROW_NUMBER() OVER (
            PARTITION BY account_id, campaign_id, adset_id, ad_id, date
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{ source('facebook_ads', 'ad_roas_insight') }}
)
WHERE row_rank = 1
