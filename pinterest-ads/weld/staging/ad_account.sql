-- staging.pinterest_ads.ad_account
-- Thin wrapper over raw `ad_account`. Casts, renames, keeps the latest row per account.
-- Grain: one row per ad account.

SELECT
    CAST(id AS STRING)               AS account_id,
    CAST(name AS STRING)             AS account_name,
    UPPER(CAST(currency AS STRING))  AS currency,
    CAST(country AS STRING)          AS account_country
FROM {{raw.pinterest_ads.ad_account}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
