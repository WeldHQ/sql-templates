-- The sales equation must hold on every row:
--   net_sales = gross_sales + line_discounts + discount_code_discounts + returns
-- (discounts and returns are stored negative, so this is plain addition.)
-- A failure is a sign error: usually a credit note stored with an unexpected sign
-- that the ABS() handling in core did not catch.

SELECT
    dandomain_shop,
    order_id,
    net_sales,
    gross_sales + line_discounts + discount_code_discounts + returns AS recomputed
FROM {{ ref('core_dandomain_webshop__sales_over_time') }}
WHERE ABS(net_sales - (gross_sales + line_discounts + discount_code_discounts + returns)) > 0.01
