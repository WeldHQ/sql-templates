-- staging.claimlane.b2c_ticket_product
-- Thin wrapper over raw `b2c_ticket_product`. One row per product line on a
-- consumer ticket: which product, how many, why.
--
-- KEY. A line is identified by ticket_id and its position on the ticket
-- (`index`), renamed product_index here because that is what the refund table
-- calls it. Join to refunds on ticket_id AND product_index.
--
-- issue_tag is the reason the shopper picked (wrong size, damaged, not as
-- described ...). Its values are configured per Claimlane account, so they are
-- kept as text rather than mapped.
--
-- unit_price is in the shop's currency, the ticket's `currency`;
-- unit_price_in_presentment_currency is what the shopper saw at checkout.

SELECT
    'account_1'                                               AS claimlane_account,
    CAST(ticket_id AS STRING)                                 AS ticket_id,
    CAST(`index` AS INT64)                                    AS product_index,
    NULLIF(TRIM(CAST(product_id AS STRING)), '')              AS product_id,
    NULLIF(TRIM(CAST(variant_id AS STRING)), '')              AS variant_id,
    NULLIF(TRIM(CAST(product_name AS STRING)), '')            AS product_name,
    NULLIF(TRIM(CAST(product_sku AS STRING)), '')             AS product_sku,
    NULLIF(TRIM(CAST(ean AS STRING)), '')                     AS ean,
    NULLIF(TRIM(CAST(issue_tag AS STRING)), '')               AS issue_tag,
    LOWER(NULLIF(TRIM(CAST(order_line_type AS STRING)), ''))  AS order_line_type,
    CAST(quantity AS NUMERIC)                                 AS quantity,
    CAST(purchased_quantity AS NUMERIC)                       AS purchased_quantity,
    CAST(unit_price AS NUMERIC)                               AS unit_price,
    CAST(unit_price_in_presentment_currency AS NUMERIC)       AS unit_price_presentment,
    CAST(exchange_item_exchange_quantity AS NUMERIC)          AS exchange_quantity
FROM {{raw.claimlane.b2c_ticket_product}}
