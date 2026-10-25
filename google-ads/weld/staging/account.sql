-- staging.google_ads.account
-- Thin wrapper over raw `account` (Google Ads customers). Casts, renames, keeps
-- the latest row per account.
-- Grain: one row per account. account_id is the Google Ads customer ID, digits only.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                 AS account_id,
        CAST(descriptive_name AS STRING)   AS account_name,
        UPPER(CAST(currency_code AS STRING)) AS currency,
        CAST(time_zone AS STRING)          AS time_zone,
        CAST(final_url_suffix AS STRING)   AS final_url_suffix,
        CAST(manager AS BOOL)              AS is_manager,
        CAST(status AS STRING)             AS account_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.google_ads.account}}
)
WHERE row_rank = 1
