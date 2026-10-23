-- core_dandomain_webshop__product_sales_over_time
-- Sales per order line, excluding VAT, with credit-note lines as returns.
--
-- Grain: day x shop x order x order line. row_type is SALE, or RETURN for the
-- lines of a credit note. Currency: the order's own. Dates: shop-local.
--
-- Depends on: staging.dandomain_webshop.order, .order_line, .order_discount_code
--
-- Same order filter as sales_over_time. Discount codes apply to the whole order,
-- so they are spread across its lines in proportion to each line's value after
-- line discounts; with that, net_sales here sums to net_sales in sales_over_time.
-- tests/assert_dandomain_webshop__product_reconciles_to_sales.sql checks it. Shipping and payment
-- fees have no product and stay in sales_over_time only.

WITH orders AS (
    SELECT
        dandomain_shop,
        order_id,
        order_created_at,
        status_id,
        currency_iso,
        IF(status_id = 100, 'RETURN', 'SALE')              AS row_type,
        IF(status_id = 100, -1, 1)                         AS sign_factor
    FROM {{ ref('stg_dandomain_webshop__order') }}
    WHERE COALESCE(status_id, -1) NOT IN (0, 5, 99)
),

codes AS (
    SELECT dandomain_shop, order_id, SUM(ABS(discount_amount)) AS discount_codes
    FROM {{ ref('stg_dandomain_webshop__order_discount_code') }}
    GROUP BY dandomain_shop, order_id
),

lines AS (
    SELECT
        l.*,
        ABS(l.unit_price * l.quantity)                     AS line_gross,
        ABS(COALESCE(l.unit_discount, 0) * l.quantity)     AS line_discount,
        o.order_created_at,
        o.status_id,
        o.currency_iso,
        o.row_type,
        o.sign_factor,
        COALESCE(c.discount_codes, 0)                      AS order_discount_codes,
        SUM(ABS(l.unit_price * l.quantity) - ABS(COALESCE(l.unit_discount, 0) * l.quantity))
            OVER (PARTITION BY l.dandomain_shop, l.order_id) AS order_after_line_discounts,
        COUNT(*) OVER (PARTITION BY l.dandomain_shop, l.order_id) AS order_line_count
    FROM {{ ref('stg_dandomain_webshop__order_line') }} l
    JOIN orders o USING (dandomain_shop, order_id)
    LEFT JOIN codes c USING (dandomain_shop, order_id)
),

allocated AS (
    SELECT
        *,
        order_discount_codes
            * COALESCE(SAFE_DIVIDE(line_gross - line_discount, NULLIF(order_after_line_discounts, 0)),
                       CAST(1 AS NUMERIC) / order_line_count) AS allocated_code_discount
    FROM lines
)

SELECT
    DATE(order_created_at)                                 AS date,
    dandomain_shop,
    order_id,
    order_line_id,
    row_type,
    status_id,
    currency_iso,
    product_id,
    variant_id,
    item_number,
    product_title,
    variant_title,
    packet_title,

    IF(row_type = 'SALE', line_gross, 0)                   AS gross_sales,
    IF(row_type = 'SALE', -line_discount, 0)               AS line_discounts,
    IF(row_type = 'SALE', -allocated_code_discount, 0)     AS discount_code_discounts,
    IF(row_type = 'RETURN',
       -(line_gross - line_discount - allocated_code_discount), 0) AS returns,
    sign_factor * (line_gross - line_discount - allocated_code_discount)  AS net_sales,
    sign_factor * ABS(quantity)                                   AS quantity,
    -- Purchase price recorded on the line at order time, times quantity. NULL or
    -- zero when the product had no buying price set.
    sign_factor * ABS(unit_buy_price * quantity)                  AS cost_of_goods
FROM allocated
