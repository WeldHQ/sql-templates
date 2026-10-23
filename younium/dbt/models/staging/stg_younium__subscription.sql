-- stg_younium__subscription
-- Younium subscriptions (orders). Younium versions a subscription on every change;
-- this keeps the latest synced version of each order number, so there is one row
-- per subscription.
--
-- This table does not include the subscription's account, so
-- subscriptions cannot be tied to customers from here.

SELECT
    CAST(id AS STRING)                                    AS subscription_id,
    CAST(order_number AS STRING)                          AS order_number,
    CAST(version AS INT64)                                AS version,
    CAST(status AS STRING)                                AS status,
    CAST(description AS STRING)                           AS description,
    CAST(order_type AS STRING)                            AS order_type,
    CAST(term_type AS STRING)                             AS term_type,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))     AS currency,
    CAST(effective_start_date AS TIMESTAMP)               AS effective_start_at,
    CAST(effective_end_date AS TIMESTAMP)                 AS effective_end_at,
    CAST(cancellation_date AS TIMESTAMP)                  AS cancelled_at,
    CAST(order_date AS TIMESTAMP)                         AS order_date,
    CAST(is_auto_renewed AS BOOL)                         AS is_auto_renewed,
    CAST(external_crm_id AS STRING)                       AS external_crm_id
FROM {{ source('younium', 'subscription') }}
WHERE order_number IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_number
    ORDER BY CAST(version AS INT64) DESC, modified DESC, _weld_synced DESC
) = 1
