-- staging.paypal.balance
-- PayPal account balances, one row per currency held, as of the last sync.
--
-- Units: decimal strings in major units, cast to NUMERIC. total = available +
-- withheld. The stream is a full refresh, so it is a snapshot, not history.

SELECT
    CAST(account_id AS STRING)                                   AS paypal_account_id,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))            AS currency,
    CAST(as_of_time AS TIMESTAMP)                                AS as_of_at,
    CAST(last_refresh_time AS TIMESTAMP)                         AS last_refreshed_at,
    COALESCE(CAST(`primary` AS BOOL), FALSE)                     AS is_primary_currency,
    SAFE_CAST(total_balance_value AS NUMERIC)                    AS total_balance,
    SAFE_CAST(available_balance_value AS NUMERIC)                AS available_balance,
    SAFE_CAST(withheld_balance_value AS NUMERIC)                 AS withheld_balance
FROM {{raw.paypal.balance}}
WHERE currency IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id, currency ORDER BY as_of_time DESC, _weld_synced DESC) = 1
