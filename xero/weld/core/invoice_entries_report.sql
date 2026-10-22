-- core.xero.invoice_entries_report
-- Invoice Entries Report. This template generates a report on invoice entries from
-- Xero, breaking down the data by year and month. It gives detailed information on
-- each invoice entry including various attributes such as invoice ID, description,
-- quantity, and so on.
--
-- From the weld.app template library. Not reconciled against Xero;
-- check the output against the source before relying on it.

SELECT
EXTRACT(YEAR FROM i.date) AS year,
EXTRACT(MONTH FROM i.date) AS month,
ili.invoice_id,
ili.description,
ili.quantity,
ili.unit_amount,
ili.tax_type,
ili.tax_amount,
ili.line_amount,
ili.account_code,
ili.item_item_id,
ili.item_name,
ili.item_code,
ili.tracking,
ili.line_item_id
FROM
{{raw.xero.invoice_line_item}} ili
-- Join the invoice table to get the date of each invoice
JOIN
{{raw.xero.invoice}} i ON ili.invoice_id = i.invoice_id
GROUP BY
1,2,
ili.invoice_id,
ili.description,
ili.quantity,
ili.unit_amount,
ili.tax_type,
ili.tax_amount,
ili.line_amount,
ili.account_code,
ili.item_item_id,
ili.item_name,
ili.item_code,
ili.tracking,
ili.line_item_id
ORDER BY
year DESC,
month DESC,
ili.invoice_id
