-- core_unleashed__sales_margin
-- Revenue, cost of goods and gross margin from completed sales orders, the
-- numbers behind Unleashed's sales enquiry and gross margin reports.
-- Grain: completed date x warehouse x customer x product x line type.
--
-- Only orders in Completed status count: that is when Unleashed dispatches stock
-- and fixes the landed cost. Revenue is the line total after discount, before
-- tax, in base currency. COGS is quantity x the average landed cost at the time
-- of sale. Charge lines (freight and similar) carry revenue but no cost; keep
-- line_type in view when reading margin per product.
--
-- Credit notes are not netted off here.

SELECT
    o.completed_date,
    o.warehouse_id,
    o.warehouse_name,
    o.customer_id,
    o.customer_code,
    o.customer_name,
    l.product_id,
    l.product_code,
    ANY_VALUE(l.product_description)                                  AS product_description,
    ANY_VALUE(p.product_group)                                        AS product_group,
    l.line_type,
    COUNT(DISTINCT o.sales_order_id)                                  AS orders,
    SUM(l.quantity)                                                   AS quantity,
    ROUND(SUM(l.bc_line_total), 2)                                    AS revenue,
    ROUND(SUM(l.quantity * COALESCE(l.unit_landed_cost, 0)), 2)       AS cogs,
    ROUND(SUM(l.bc_line_total - l.quantity * COALESCE(l.unit_landed_cost, 0)), 2) AS gross_margin,
    SAFE_DIVIDE(SUM(l.bc_line_total - l.quantity * COALESCE(l.unit_landed_cost, 0)),
                SUM(l.bc_line_total))                                 AS gross_margin_pct,
    COUNTIF(l.unit_landed_cost IS NULL AND l.product_id IS NOT NULL)  AS lines_without_cost
FROM {{ ref('stg_unleashed__sales_order') }} o
JOIN {{ ref('stg_unleashed__sales_order_line') }} l USING (sales_order_id)
LEFT JOIN {{ ref('stg_unleashed__product') }} p ON p.product_id = l.product_id
WHERE o.order_status = 'Completed'
GROUP BY o.completed_date, o.warehouse_id, o.warehouse_name, o.customer_id, o.customer_code,
         o.customer_name, l.product_id, l.product_code, l.line_type
