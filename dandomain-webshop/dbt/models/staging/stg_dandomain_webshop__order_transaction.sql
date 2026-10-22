-- stg_dandomain_webshop__order_transaction
-- Thin wrapper over raw `order_transaction`: payment gateway transactions per
-- order, latest copy per row.
--
-- status: 0 awaiting, 1 completed, 2 cancelled, 3 refunded. A refund changes the
-- status of the original transaction in place; there is no separate refund row and
-- no refund date. amount_full is used for money; `amount` is an integer and is not.

SELECT
    'shop_1'                                        AS dandomain_shop,
    CAST(id AS INT64)                               AS transaction_id,
    CAST(order_id AS INT64)                         AS order_id,
    CAST(date AS TIMESTAMP)                         AS transaction_at,
    CAST(status AS INT64)                           AS status,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), '')) AS currency,
    NULLIF(TRIM(CAST(cardtype AS STRING)), '')      AS card_type,
    CAST(amount_full AS NUMERIC)                    AS amount
FROM {{ source('dandomain_webshop', 'order_transaction') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
