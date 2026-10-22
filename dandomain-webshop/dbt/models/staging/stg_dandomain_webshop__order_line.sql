-- stg_dandomain_webshop__order_line
-- Thin wrapper over raw `order_line`, latest copy per line.
--
-- MONEY EXCLUDES VAT. DanDomain documents price and discount on an order line as
-- "without VAT". price is the unit price; vat is the VAT recorded on the line and
-- buy_price the purchase price at the time of the order. DanDomain does not say
-- whether discount is per unit or for the whole line: it is treated as per unit
-- here, like price. Check one discounted line with quantity above 1 against its
-- invoice; if the discount is per line, change one expression in core.
--
-- Bundles ("packets") arrive as one line carrying the price, with the bundle's
-- contents in packet_lines_item as JSON. Only the priced line is used, so a bundle
-- is counted once.

SELECT
    'shop_1'                                            AS dandomain_shop,
    CAST(id AS INT64)                                   AS order_line_id,
    CAST(order_id AS INT64)                             AS order_id,
    CAST(product_id AS INT64)                           AS product_id,
    CAST(variant_id AS INT64)                           AS variant_id,
    NULLIF(TRIM(CAST(item_number AS STRING)), '')       AS item_number,
    NULLIF(TRIM(CAST(product_title AS STRING)), '')     AS product_title,
    NULLIF(TRIM(CAST(variant_title AS STRING)), '')     AS variant_title,
    NULLIF(TRIM(CAST(packet_title AS STRING)), '')      AS packet_title,
    CAST(amount AS INT64)                               AS quantity,
    CAST(price AS NUMERIC)                              AS unit_price,
    CAST(discount AS NUMERIC)                           AS unit_discount,
    CAST(vat AS NUMERIC)                                AS unit_vat,
    CAST(vat_rate AS NUMERIC)                           AS vat_rate,
    CAST(buy_price AS NUMERIC)                          AS unit_buy_price
FROM {{ source('dandomain_webshop', 'order_line') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
