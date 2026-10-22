-- staging.reddit_ads.ad_account
-- Thin wrapper over raw `ad_account`. Casts, renames, keeps the latest row per account.
-- Grain: one row per ad account.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                       AS account_id,
        CAST(name AS STRING)                     AS account_name,
        UPPER(CAST(currency AS STRING))          AS currency,
        CAST(time_zone_id AS STRING)             AS time_zone_id,
        CAST(click_attribution_window AS STRING) AS click_attribution_window,
        CAST(view_attribution_window AS STRING)  AS view_attribution_window,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.reddit_ads.ad_account}}
)
WHERE row_rank = 1
