-- core_dandomain_webshop__sales_over_time
-- The sales equation per order per day, excluding VAT, with credit notes as
-- returns on the day they were issued.
--
-- Grain: day x shop x order. A credit note is its own order in DanDomain, so it
-- has its own row, typed RETURN; ordinary orders are typed SALE.
-- Currency: the order's own (currency_iso). Do not sum across currencies.
-- Dates: shop-local, as DanDomain returns them; see staging.order.
--
-- Depends on: staging.dandomain_webshop.order, .order_line, .order_discount_code,
--             .order_transaction, .order_status_code
--
-- WHICH ORDERS COUNT. Dropped: 0 Not received, 5 Cancelled and 99 Draft. Status
-- 100 is a credit note and becomes a RETURN row. Everything else is a SALE,
-- including Order received and Processing.
--
-- RETURNS ARE CREDIT NOTES, AND ONLY CREDIT NOTES. A credit note is valued from its
-- own lines and forced negative, whichever sign the shop stored it with, so it
-- always reduces sales. The connector syncs no link from a credit note to the
-- order it credits, so a return cannot be traced to its original sale here.
-- Refunds made only at the payment gateway, with no credit note, are not in the
-- sales equation; refunded_payments shows them on the original order's row, dated
-- on the order, because DanDomain records no refund date.
--
-- WHY THE EQUATION IS VAT-EXCLUSIVE. DanDomain documents line prices and discounts
-- without VAT, and shipping and payment fees with only a has-VAT flag. A
-- VAT-inclusive total would rest on assumptions about how VAT is applied to
-- discount codes, which the API does not document. line_vat is the VAT recorded on
-- the lines, passed through as stored.

WITH orders AS (
    SELECT
        o.*,
        IF(o.status_id = 100, 'RETURN', 'SALE')            AS row_type,
        IF(o.status_id = 100, -1, 1)                       AS sign_factor,
        sc.status_title
    FROM {{ ref('stg_dandomain_webshop__order') }} o
    LEFT JOIN {{ ref('stg_dandomain_webshop__order_status_code') }} sc USING (dandomain_shop, status_id)
    WHERE COALESCE(o.status_id, -1) NOT IN (0, 5, 99)
),

-- Each child table is pre-aggregated to one row per order before joining, so no
-- join can fan out another's money.
lines AS (
    SELECT
        dandomain_shop,
        order_id,
        SUM(ABS(unit_price * quantity))                    AS gross,
        SUM(ABS(COALESCE(unit_discount, 0) * quantity))    AS line_discounts,
        SUM(ABS(COALESCE(unit_vat, 0) * quantity))         AS line_vat,
        SUM(ABS(quantity))                                 AS quantity
    FROM {{ ref('stg_dandomain_webshop__order_line') }}
    GROUP BY dandomain_shop, order_id
),

codes AS (
    SELECT dandomain_shop, order_id, SUM(discount_amount) AS discount_codes
    FROM {{ ref('stg_dandomain_webshop__order_discount_code') }}
    GROUP BY dandomain_shop, order_id
),

payments AS (
    SELECT
        dandomain_shop,
        order_id,
        SUM(IF(status = 1, amount, 0))                     AS captured_payments,
        SUM(IF(status = 3, amount, 0))                     AS refunded_payments
    FROM {{ ref('stg_dandomain_webshop__order_transaction') }}
    GROUP BY dandomain_shop, order_id
),

joined AS (
    SELECT
        o.*,
        COALESCE(l.gross, 0)                               AS gross,
        COALESCE(l.line_discounts, 0)                      AS line_discounts,
        COALESCE(l.line_vat, 0)                            AS line_vat_abs,
        COALESCE(l.quantity, 0)                            AS line_quantity,
        COALESCE(c.discount_codes, 0)                      AS discount_codes,
        p.captured_payments,
        p.refunded_payments
    FROM orders o
    LEFT JOIN lines l    USING (dandomain_shop, order_id)
    LEFT JOIN codes c    USING (dandomain_shop, order_id)
    LEFT JOIN payments p USING (dandomain_shop, order_id)
)

SELECT
    DATE(order_created_at)                                 AS date,
    dandomain_shop,
    order_id,
    row_type,
    status_id,
    status_title,
    currency_iso,
    site_id,
    origin,
    language_iso,
    COALESCE(shipping_country_code, customer_country_code) AS country_code,
    user_id,
    is_b2b,
    invoice_number,

    -- The sales equation, VAT excluded. Discounts and returns are negative. A
    -- credit note puts its whole value into returns and nothing into gross, so a
    -- SALE row and a RETURN row never mix.
    IF(row_type = 'SALE', gross, 0)                        AS gross_sales,
    IF(row_type = 'SALE', -line_discounts, 0)              AS line_discounts,
    IF(row_type = 'SALE', -ABS(discount_codes), 0)         AS discount_code_discounts,
    IF(row_type = 'RETURN',
       -(gross - line_discounts - ABS(discount_codes)), 0) AS returns,
    sign_factor * (gross - line_discounts - ABS(discount_codes))  AS net_sales,
    sign_factor * ABS(COALESCE(delivery_price, 0))                AS shipping,
    sign_factor * ABS(COALESCE(payment_fee, 0))                   AS payment_fees,
    sign_factor * (gross - line_discounts - ABS(discount_codes)
            + ABS(COALESCE(delivery_price, 0))
            + ABS(COALESCE(payment_fee, 0)))               AS total_sales_ex_vat,
    sign_factor * line_vat_abs                                    AS line_vat,
    vat_percentage,
    delivery_has_vat,
    payment_has_vat,

    -- For reconciliation only. DanDomain's deprecated order total is documented as
    -- lines without VAT, shipping or fees, so it should be close to net_sales on a
    -- SALE row. A large gap on many orders means the discount is per line, not
    -- per unit; see staging.order_line.
    reported_total_deprecated,

    -- Payment gateway figures, as recorded. Not part of the equation.
    captured_payments,
    refunded_payments,

    sign_factor * line_quantity                                   AS quantity,
    IF(row_type = 'SALE', 1, 0)                            AS orders,
    IF(row_type = 'RETURN', 1, 0)                          AS credit_notes
FROM joined
