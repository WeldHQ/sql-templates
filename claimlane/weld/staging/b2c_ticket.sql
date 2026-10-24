-- staging.claimlane.b2c_ticket
-- Thin wrapper over raw `b2c_ticket`. One row per consumer ticket: a return,
-- warranty claim, damaged or missing item, submitted by a shopper.
--
-- PERSONAL DATA IS LEFT OUT ON PURPOSE. The raw table carries the consumer's
-- name, email, phone, street address and, on refund tickets, bank details
-- (IBAN, account number, sort code). None of it is needed to count or value
-- claims, so none of it is selected here, and nothing downstream can leak it
-- into a dashboard. Country is kept for geography.
--
-- NO STATUS, NO CLOSE DATE. The connector syncs when a ticket was created but
-- not when it was resolved, and carries no open/closed status for consumer
-- tickets. Resolution time cannot be built from this table; see the README.
--
-- The connector re-reads every consumer ticket on each sync, because tickets keep
-- changing after they are created, so the table reflects each ticket as it is now.

SELECT
    'account_1'                                                         AS claimlane_account,
    CAST(ticket_id AS STRING)                                           AS ticket_id,
    CAST(organization_id AS STRING)                                     AS organization_id,
    CAST(is_archived AS BOOL)                                           AS is_archived,
    NULLIF(TRIM(CAST(rma_number AS STRING)), '')                        AS rma_number,
    NULLIF(TRIM(CAST(ticket_type AS STRING)), '')                       AS ticket_type,
    NULLIF(TRIM(CAST(channel_type AS STRING)), '')                      AS channel_type,
    CAST(created_at AS TIMESTAMP)                                       AS created_at,
    NULLIF(TRIM(CAST(suggested_solution AS STRING)), '')                AS suggested_solution,
    NULLIF(TRIM(CAST(action_label AS STRING)), '')                      AS action_label,
    NULLIF(TRIM(CAST(return_automation_status AS STRING)), '')          AS return_automation_status,
    NULLIF(TRIM(CAST(order_id AS STRING)), '')                          AS order_id,
    NULLIF(TRIM(CAST(order_number AS STRING)), '')                      AS order_number,
    CAST(order_date_unix AS TIMESTAMP)                                  AS order_at,
    UPPER(NULLIF(TRIM(CAST(address_country_code AS STRING)), ''))       AS consumer_country_code,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))                   AS currency,
    -- refund, storeCredit, exchange or keepProduct: what the consumer gets back.
    NULLIF(TRIM(CAST(return_type AS STRING)), '')                       AS return_type,
    -- Claimlane's price for the return itself (typically a return shipping fee
    -- the shopper pays), in its own currency. Claimlane documents it only as a
    -- number, so it is passed through and not used in any refund figure.
    CAST(return_price AS NUMERIC)                                       AS return_price,
    UPPER(NULLIF(TRIM(CAST(return_price_currency AS STRING)), ''))      AS return_price_currency,
    CAST(entire_order_returned AS BOOL)                                 AS entire_order_returned,
    NULLIF(TRIM(CAST(shop_url AS STRING)), '')                          AS shop_url,
    NULLIF(TRIM(CAST(supplier_name AS STRING)), '')                     AS supplier_name,
    CAST(refund_information_original_shipping_refunded AS BOOL)         AS original_shipping_refunded,
    CAST(refund_information_original_shipping_refunded_amount AS NUMERIC) AS original_shipping_refunded_amount,
    UPPER(NULLIF(TRIM(CAST(refund_information_original_shipping_refunded_amount_currency AS STRING)), ''))
                                                                        AS original_shipping_refunded_currency
FROM {{raw.claimlane.b2c_ticket}}
