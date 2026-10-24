-- staging.shiphero.return
-- Thin wrapper over raw `return`. One row per return (RMA).
--
-- STATUS AND RECEIVED COUNTS LAG. Returns are picked up by creation date, so
-- a return created weeks ago and received today keeps its old status and received
-- counts until that period is re-synced.

SELECT
    'account_1'                                      AS shiphero_account,
    CAST(id AS STRING)                               AS return_id,
    CAST(order_id AS STRING)                         AS order_id,
    CAST(account_id AS STRING)                       AS account_id,
    NULLIF(TRIM(CAST(reason AS STRING)), '')         AS reason,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))  AS status,
    SAFE_CAST(label_cost AS NUMERIC)                 AS label_cost,
    SAFE_CAST(cost_to_customer AS NUMERIC)           AS cost_to_customer,
    CAST(total_items_expected AS INT64)              AS items_expected,
    CAST(total_items_received AS INT64)              AS items_received,
    CAST(total_items_restocked AS INT64)             AS items_restocked,
    CAST(created_at AS TIMESTAMP)                    AS created_at
FROM {{raw.shiphero.return}}
