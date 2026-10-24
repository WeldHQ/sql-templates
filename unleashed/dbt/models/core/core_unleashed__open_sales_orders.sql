-- core_unleashed__open_sales_orders
-- Sales orders placed but not yet completed: the order book, with how late each
-- order is against its required date. A snapshot as of the last sync.
-- Grain: sales order.
--
-- Open means Placed or Backordered. Parked orders are drafts and are left out.
-- Value is in base currency, before tax.

SELECT
    o.sales_order_id,
    o.order_number,
    o.order_status,
    o.custom_order_status,
    o.customer_code,
    o.customer_name,
    o.warehouse_name,
    o.salesperson_name,
    o.order_date,
    o.required_date,
    DATE_DIFF(CURRENT_DATE(), o.order_date, DAY)                       AS days_open,
    GREATEST(DATE_DIFF(CURRENT_DATE(), o.required_date, DAY), 0)       AS days_past_required,
    o.required_date < CURRENT_DATE()                                   AS is_late,
    o.currency,
    o.sub_total,
    o.bc_sub_total                                                     AS value_base_currency
FROM {{ ref('stg_unleashed__sales_order') }} o
WHERE o.order_status IN ('Placed', 'Backordered')
