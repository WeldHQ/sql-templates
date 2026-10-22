-- core_economic__invoice_line_items
-- Invoice line items. Retrieves invoice line items from the economic integration.
-- It combines data from the "booked_invoices" table and the "products" and
-- "customers" tables to provide information such as the customer name, invoice
-- details, product details, and order by date in descending order.
--
-- From the weld.app template library. Not reconciled against e-conomic;
-- check the output against the source before relying on it.

with invoice_items as ( select date as date , concat(invoiceNumber, lineNumber) as invoice_line_id , invoiceNumber as invoice_id , i.customer_customerNumber as customer_id , invoiceType as invoice_type , currency , a.quantity as quantity , a.lineNumber as line_id , a.unitNetPrice as unit_net_price , a.discountPercentage as discount_percentage , a.unitCostPrice as unit_cost_price , a.vatRate as vat_rate , a.vatamount as vat_amount , a.totalNetAmount as net_amount_excl_tax , (a.totalNetAmount + a.vatamount) as net_amount_incl_tax , json_value(a.product, '$.productNumber') as product_id from {{ source('economic', 'booked_invoices') }} i left join unnest (lines) as a ) select c.name , i.* from invoice_items i left join {{ source('economic', 'products') }} p on i.product_id = p.productNumber left join {{ source('economic', 'customers') }} c on i.customer_id = c.customerNumber order by date desc
