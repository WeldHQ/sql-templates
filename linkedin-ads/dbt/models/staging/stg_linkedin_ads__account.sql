-- stg_linkedin_ads__account
-- Thin wrapper over raw `account`. Casts, renames, keeps the latest row per ad account.
-- Grain: one row per ad account.
--
-- The connector reads every ad account the authorising user can see, not only the
-- ones selected for sync, so this table can hold accounts with no delivery.

SELECT
    CAST(id AS STRING)               AS account_id,
    CAST(name AS STRING)             AS account_name,
    UPPER(CAST(currency AS STRING))  AS currency,
    CAST(status AS STRING)           AS account_status,
    CAST(type AS STRING)             AS account_type,
    CAST(test AS BOOL)               AS is_test_account,
    CAST(reference AS STRING)        AS reference
FROM {{ source('linkedin_ads', 'account') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
