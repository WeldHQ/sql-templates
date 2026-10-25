-- staging.microsoft_ads.account
-- Thin wrapper over raw `account`. Casts, renames, keeps the latest row per account.
-- Grain: one row per Microsoft Advertising account.
--
-- account_id is the numeric account ID that the reports carry. account_number is
-- the short code shown in the Microsoft Advertising UI (e.g. F1234ABC).

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                    AS account_id,
        CAST(number AS STRING)                AS account_number,
        CAST(name AS STRING)                  AS account_name,
        UPPER(CAST(currency_code AS STRING))  AS currency,
        CAST(time_zone AS STRING)             AS time_zone,
        CAST(account_life_cycle_status AS STRING) AS account_status,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.microsoft_ads.account}}
)
WHERE row_rank = 1
