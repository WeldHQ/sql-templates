-- stg_netsuite__account
-- The chart of accounts, from the REST `account` record.
--
-- Grain: one row per account.
--
-- This table comes from NetSuite's REST record catalog rather than a fixed
-- SuiteQL query, so its columns are whatever NetSuite's metadata describes for
-- your account. The ones used here (id, acct_number, acct_name, acct_type,
-- is_inactive) are standard on the account record. Reference fields such as
-- acct_type arrive as a JSON object ({"id": "Income", "refName": "Income"}); the
-- id is the account type code that staging.netsuite.account_type is keyed on.
--
-- Single NetSuite account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different netsuite_account label.

SELECT
    'account_1'                                                   AS netsuite_account,
    CAST(id AS STRING)                                            AS account_id,
    NULLIF(TRIM(CAST(acct_number AS STRING)), '')                 AS account_number,
    CAST(acct_name AS STRING)                                     AS account_name,
    COALESCE(
        JSON_VALUE(CAST(acct_type AS STRING), '$.id'),
        CAST(acct_type AS STRING)
    )                                                             AS account_type_id,
    COALESCE(CAST(is_inactive AS BOOL), FALSE)                    AS is_inactive
FROM {{ source('netsuite', 'account') }}
