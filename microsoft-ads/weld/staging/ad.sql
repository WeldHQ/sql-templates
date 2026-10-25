-- staging.microsoft_ads.ad
-- Thin wrapper over raw `ad`. Casts, renames, keeps the latest row per ad.
-- Grain: one row per ad. parent_id is the ad group ID.
--
-- Microsoft ads have no name field. ad_name is the ad's title, which responsive
-- search ads and some other types leave empty; final_url is the landing page.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)         AS ad_id,
        CAST(parent_id AS STRING)  AS ad_group_id,
        CAST(account_id AS STRING) AS account_id,
        CAST(title AS STRING)      AS ad_name,
        CAST(status AS STRING)     AS ad_status,
        CAST(final_url AS STRING)  AS final_url,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.microsoft_ads.ad}}
)
WHERE row_rank = 1
