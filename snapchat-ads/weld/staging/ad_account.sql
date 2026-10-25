-- staging.snapchat_ads.ad_account
-- Thin wrapper over raw `ad_account`. Casts, renames, keeps the latest row per account.
-- Grain: one row per ad account.
--
-- timezone is the IANA name (e.g. America/Los_Angeles) that Snapchat uses for the
-- account's reporting day; core needs it to turn report timestamps into dates.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)               AS account_id,
        CAST(name AS STRING)             AS account_name,
        UPPER(CAST(currency AS STRING))  AS currency,
        CAST(timezone AS STRING)         AS account_timezone,
        CAST(organization_id AS STRING)  AS organization_id,
        CAST(type AS STRING)             AS account_type,
        CAST(status AS STRING)           AS account_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.snapchat_ads.ad_account}}
)
WHERE row_rank = 1
