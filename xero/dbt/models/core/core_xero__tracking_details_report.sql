-- core_xero__tracking_details_report
-- Tracking Details Report. This template generates a report that brings together
-- tracking details from journal and invoice records, outlining essential details
-- including source type, source ID, and financial particulars such as net and gross
-- amounts, tax details, and tracking categories.
--
-- From the weld.app template library. Not reconciled against Xero;
-- check the output against the source before relying on it.

WITH JournalTracking AS (
SELECT
'Journal' AS source,
journal_id AS source_id,
description,
net_amount,
gross_amount,
tax_amount,
tax_type,
tax_name,
tracking_categories AS tracking
FROM
{{ source('xero', 'journal_line') }}
),
-- Next, we'll collect data from the invoice_line_item table
InvoiceTracking AS (
SELECT
'Invoice' AS source,
invoice_id AS source_id,
description,
NULL AS net_amount,
line_amount AS gross_amount,
tax_amount,
tax_type,
NULL AS tax_name,
tracking
FROM
{{ source('xero', 'invoice_line_item') }}
)
-- Now, we'll union these two CTEs to create the report
SELECT
source,
source_id,
description,
net_amount,
gross_amount,
tax_amount,
tax_type,
tax_name,
tracking
FROM
JournalTracking
UNION ALL
SELECT
source,
source_id,
description,
net_amount,
gross_amount,
tax_amount,
tax_type,
cast(tax_name as string),
tracking
FROM
InvoiceTracking
ORDER BY
source,
tracking
