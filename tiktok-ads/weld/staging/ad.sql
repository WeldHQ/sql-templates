-- staging.tiktok_ads.ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per advertiser and ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)    AS account_id,
        CAST(id AS STRING)               AS ad_id,
        CAST(ad_name AS STRING)          AS ad_name,
        CAST(ad_group_id AS STRING)      AS ad_group_id,
        CAST(campaign_id AS STRING)      AS campaign_id,
        CAST(ad_format AS STRING)        AS ad_format,
        CAST(video_id AS STRING)         AS video_id,
        CAST(landing_page_url AS STRING) AS landing_page_url,
        CAST(opt_status AS STRING)       AS ad_status,
        ROW_NUMBER() OVER (PARTITION BY advertiser_id, id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.tiktok_ads.ad}}
)
WHERE row_rank = 1
