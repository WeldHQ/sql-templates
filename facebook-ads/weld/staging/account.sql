-- staging.facebook_ads.account
-- Thin wrapper over raw `account`. Casts, renames, keeps the latest row per account.
-- Grain: one row per ad account.
--
-- account_id is the numeric ad account ID without Meta's "act_" prefix, which is
-- how the connector lands it. The prefix is stripped anyway, so IDs pasted from
-- Ads Manager URLs or other tools join cleanly.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        REGEXP_REPLACE(CAST(id AS STRING), r'^act_', '') AS account_id,
        CAST(name AS STRING)                             AS account_name,
        UPPER(CAST(currency AS STRING))                  AS currency,
        CAST(account_status AS INT64)                    AS account_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.facebook_ads.account}}
)
WHERE row_rank = 1
