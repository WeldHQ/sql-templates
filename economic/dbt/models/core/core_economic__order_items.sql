-- core_economic__order_items
-- Order items. Retrieves order items from the "economic" integration. It combines
-- data from the "orders" table and the "customers" table, joining them based on the
-- customer ID. The result is sorted in descending order by date.
--
-- From the weld.app template library. Not reconciled against e-conomic;
-- check the output against the source before relying on it.

with order_items as ( select date as date ,orderNumber as order_id , concat(orderNumber, lineNumber) as order_line_id , i.customer_customerNumber as customer_id , orderType as invoice_type , currency , a.lineNumber as line_id , a.description , a.unit ,a.quantity ,a.unitNetPrice as unit_net_price ,a.discountPercentage as discount_percentage ,a.unitCostPrice as unit_cost_price ,a.totalNetAmount as total_net_amount ,a.marginInBaseCurrency as margin_in_base_currency ,a.marginPercentage as margin_percentage ,a.departmentalDistribution as departmental_distribution from {{ source('economic', 'orders') }} i left join unnest (lines) as a ) select c.name , i.* from order_items i left join {{ source('economic', 'customers') }} c on i.customer_id = c.customerNumber order by date desc
