-- stg_claimlane__b2c_ticket_product_refund
-- Thin wrapper over raw `b2c_ticket_product_refund`. One row per refund booked
-- against a product line; a line can be refunded in several steps.
--
-- Joins to staging.claimlane.b2c_ticket_product on ticket_id and product_index.
-- Aggregate to the line before joining, or a line refunded twice doubles its
-- claimed value.
--
-- Claimlane does not state a currency on the refund itself. The models treat it
-- as the ticket's currency, which is the shop currency the order was placed in.

SELECT
    'account_1'                              AS claimlane_account,
    CAST(ticket_id AS STRING)                AS ticket_id,
    CAST(product_index AS INT64)             AS product_index,
    CAST(`index` AS INT64)                   AS refund_index,
    CAST(refunded_quantity AS NUMERIC)       AS refunded_quantity,
    CAST(refunded_amount AS NUMERIC)         AS refunded_amount,
    CAST(shipping_cost AS NUMERIC)           AS refunded_shipping_cost
FROM {{ source('claimlane', 'b2c_ticket_product_refund') }}
