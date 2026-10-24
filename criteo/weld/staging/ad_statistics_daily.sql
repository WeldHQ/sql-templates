-- staging.criteo.ad_statistics_daily
-- Thin wrapper over raw `ad_statistics_daily_report`. Casts, renames, de-duplicates.
-- No other logic.
--
-- Grain: date x campaign x ad set x ad. Criteo reports spend it cannot tie to an
-- ad under the placeholder ad id "-1", once per ad set, so the ad id alone is not
-- unique within a day; the campaign and ad set ids are part of the key.
--
-- Money is in the currency chosen in the connector settings (one currency for
-- every advertiser), in whole units, not micros. Dates are calendar days in the
-- timezone chosen in the connector settings, UTC when none is set.
--
-- If a day is synced more than once, the latest synced row per key wins.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        SAFE_CAST(date AS DATE)                                AS date_day,
        CAST(campaign_id AS STRING)                            AS campaign_id,
        CAST(adset_id AS STRING)                               AS adset_id,
        CAST(ad_id AS STRING)                                  AS ad_id,
        CAST(campaign AS STRING)                               AS campaign_name,
        CAST(adset AS STRING)                                  AS adset_name,
        CAST(ad AS STRING)                                     AS ad_name,
        UPPER(CAST(currency AS STRING))                        AS currency,
        CAST(COALESCE(advertiser_cost, 0) AS NUMERIC)          AS spend,
        CAST(COALESCE(displays, 0) AS INT64)                   AS impressions,
        CAST(COALESCE(clicks, 0) AS INT64)                     AS clicks,
        CAST(COALESCE(sales_pc_30_d, 0) AS NUMERIC)            AS sales_pc_30d,
        CAST(COALESCE(revenue_generated_pc_30_d, 0) AS NUMERIC) AS revenue_pc_30d,
        CAST(COALESCE(sales_all_pc_30_d, 0) AS NUMERIC)        AS sales_all_pc_30d,
        CAST(COALESCE(revenue_generated_all_pc_30_d, 0) AS NUMERIC) AS revenue_all_pc_30d,
        CAST(COALESCE(sales_pv_24_h, 0) AS NUMERIC)            AS sales_pv_24h,
        CAST(COALESCE(revenue_generated_pv_24_h, 0) AS NUMERIC) AS revenue_pv_24h,
        CAST(COALESCE(sales_client_attribution, 0) AS NUMERIC) AS sales_client_attribution,
        CAST(COALESCE(revenue_generated_client_attribution, 0) AS NUMERIC) AS revenue_client_attribution,
        CAST(visits AS NUMERIC)                                AS visits,
        ROW_NUMBER() OVER (
            PARTITION BY date, campaign_id, adset_id, ad_id
            ORDER BY _weld_synced DESC
        ) AS row_rank
    FROM {{raw.criteo.ad_statistics_daily_report}}
)
WHERE row_rank = 1
