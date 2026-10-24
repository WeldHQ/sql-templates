-- stg_tiktok_shop__return_order
-- Thin wrapper over raw `return_order`: one row per return or refund request,
-- latest version only.
--
-- TikTok has no "refunded at" timestamp on a return. For a request that reached
-- RETURN_OR_REFUND_REQUEST_COMPLETE, update_time is when it completed, which is
-- when the refund was issued, so core uses it as the refund date. A later edit
-- to a completed return (arbitration, for example) moves that date.

SELECT
    'account_1'                                   AS tiktok_account,
    CAST(shop_id AS STRING)                       AS shop_id,
    CAST(return_id AS STRING)                     AS return_id,
    CAST(order_id AS STRING)                      AS order_id,
    UPPER(CAST(return_type AS STRING))            AS return_type,
    UPPER(CAST(return_status AS STRING))          AS return_status,
    CAST(return_reason AS STRING)                 AS return_reason,
    CAST(return_reason_text AS STRING)            AS return_reason_text,
    CAST(create_time AS TIMESTAMP)                AS created_at,
    CAST(update_time AS TIMESTAMP)                AS updated_at,
    UPPER(CAST(refund_amount_currency AS STRING)) AS currency,
    CAST(refund_amount_refund_total AS NUMERIC)   AS refund_total,
    CAST(partial_refund_amount AS NUMERIC)        AS partial_refund_amount
FROM {{ source('tiktok_shop', 'return_order') }}
WHERE return_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, return_id ORDER BY update_time DESC, _weld_synced DESC) = 1
