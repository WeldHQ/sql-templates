-- staging.bigcommerce.refund
-- Thin wrapper over raw `refund`: one row per refund created through BigCommerce's
-- refunds (payment actions) flow. Timestamps are UTC.
--
-- total_amount is the money given back, tax included; total_tax is the tax part of
-- it. Both stay positive here; core decides the sign.

SELECT
    'store_1'                                   AS bigcommerce_store,
    CAST(id AS INT64)                           AS refund_id,
    CAST(order_id AS INT64)                     AS order_id,
    CAST(created AS TIMESTAMP)                  AS created_at,
    NULLIF(TRIM(CAST(reason AS STRING)), '')    AS reason,
    CAST(total_amount AS NUMERIC)               AS total_amount,
    CAST(total_tax AS NUMERIC)                  AS total_tax
FROM {{raw.bigcommerce.refund}}
