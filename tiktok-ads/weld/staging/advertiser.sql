-- staging.tiktok_ads.advertiser
-- Thin wrapper over raw `advertiser`. An advertiser is TikTok's ad account.
-- Casts, renames, keeps the latest row per advertiser.
-- Grain: one row per advertiser.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)               AS account_id,
        CAST(name AS STRING)             AS account_name,
        UPPER(CAST(currency AS STRING))  AS currency,
        CAST(timezone AS STRING)         AS account_timezone,
        CAST(status AS STRING)           AS account_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.tiktok_ads.advertiser}}
)
WHERE row_rank = 1
