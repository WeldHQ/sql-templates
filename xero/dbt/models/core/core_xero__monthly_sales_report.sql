-- core_xero__monthly_sales_report
-- Monthly Sales Report. This template creates a monthly sales report by analyzing
-- invoice data. It breaks down sales numbers and revenue per product/service and
-- item code on a monthly basis, offering a clear view of how different offerings
-- perform over time.
--
-- Grain: year x month x currency x item. Only sales invoices (type ACCREC)
-- that are approved or paid count; drafts, voided and deleted invoices and
-- supplier bills are left out. Revenue is the line amount in the invoice
-- currency, so each currency gets its own rows. Line amounts are net or gross
-- of tax depending on how each invoice was entered (line_amount_types).
--
-- From the weld.app template library, corrected. Not reconciled against Xero;
-- check the output against the source before relying on it.

SELECT
EXTRACT(YEAR FROM i.date) AS year,
EXTRACT(MONTH FROM i.date) AS month,
i.currency_code,
ili.item_name AS product_service,
ili.item_code,
COUNT(ili.line_item_id) AS number_of_sales,
SUM(ili.line_amount) AS monthly_revenue
FROM
{{ source('xero', 'invoice_line_item') }} ili
-- Join the invoice table to get the date of each invoice
JOIN
{{ source('xero', 'invoice') }} i ON ili.invoice_id = i.invoice_id
WHERE
i.type = 'ACCREC'
AND i.status IN ('AUTHORISED', 'PAID')
GROUP BY
year,
month,
i.currency_code,
ili.item_name,
ili.item_code
ORDER BY
year DESC,
month DESC,
monthly_revenue DESC
