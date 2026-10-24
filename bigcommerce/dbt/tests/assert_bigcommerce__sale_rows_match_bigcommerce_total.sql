-- Every SALE row must reproduce BigCommerce's own order total:
--   total_sales = total_inc_tax
-- Discounts are derived from BigCommerce's totals, so this holds by construction
-- unless total_inc_tax != total_ex_tax + total_tax on the order, or a component
-- column went NULL. A failure points at the order, not at the equation.
--
-- Returns zero rows when it holds. A cent of tolerance absorbs rounding.

SELECT
    bigcommerce_store,
    order_id,
    total_sales,
    reported_total_inc_tax,
    total_sales - reported_total_inc_tax AS diff
FROM {{ ref('core_bigcommerce__sales_over_time') }}
WHERE row_type = 'SALE'
  AND ABS(total_sales - COALESCE(reported_total_inc_tax, 0)) > 0.01
