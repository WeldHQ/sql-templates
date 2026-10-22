-- core.xero.monthly_sales_report
-- Monthly Sales Report. This template creates a monthly sales report by analyzing
-- invoice data. It breaks down sales numbers and revenue per product/service and
-- item code on a monthly basis, offering a clear view of how different offerings
-- perform over time.
--
-- From the weld.app template library. Not reconciled against Xero;
-- check the output against the source before relying on it.

SELECT
EXTRACT(YEAR FROM i.date) AS year,
EXTRACT(MONTH FROM i.date) AS month,
ili.item_name AS product_service,
ili.item_code,
COUNT(ili.line_item_id) AS number_of_sales,
SUM(ili.line_amount) AS monthly_revenue
FROM
invoice_line_item ili
-- Join the invoice table to get the date of each invoice
JOIN
invoice i ON ili.invoice_id = i.invoice_id
GROUP BY
EXTRACT(YEAR FROM i.date),
EXTRACT(MONTH FROM i.date),
ili.item_name,
ili.item_code
ORDER BY
year DESC,
month DESC,
monthly_revenue DESC
