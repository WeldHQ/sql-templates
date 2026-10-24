# Xero templates

SQL reports over Weld's Xero connector. BigQuery.

| Model | Report | What it returns |
|---|---|---|
| [`weld/core/invoice_entries_report.sql`](weld/core/invoice_entries_report.sql) · [dbt](dbt/models/core/core_xero__invoice_entries_report.sql) | Invoice Entries Report | This template generates a report on invoice entries from Xero, breaking down the data by year and month. It gives detailed information on each invoice entry including various attributes such as invoice ID, description, quantity, and so on. |
| [`weld/core/journal_entries_report.sql`](weld/core/journal_entries_report.sql) · [dbt](dbt/models/core/core_xero__journal_entries_report.sql) | Journal Entries Report | This template generates a report on journal entries from Xero, breaking down the data by year and month. It gives you a count of all journal entries and a count of individual journal lines for each journal entry within the specified periods. |
| [`weld/core/monthly_invoice_summary_report.sql`](weld/core/monthly_invoice_summary_report.sql) · [dbt](dbt/models/core/core_xero__monthly_invoice_summary_report.sql) | Monthly Invoice Summary Report | This template generates a monthly invoice summary report from Xero, organizing the data by year and month. It details various invoice metrics such as the total number and amount of invoices, total tax, total amount due and paid, amount credited, and the number of unique contacts involved. |
| [`weld/core/monthly_sales_report.sql`](weld/core/monthly_sales_report.sql) · [dbt](dbt/models/core/core_xero__monthly_sales_report.sql) | Monthly Sales Report | This template creates a monthly sales report by analyzing invoice data. It breaks down sales numbers and revenue per product/service and item code on a monthly basis, offering a clear view of how different offerings perform over time. |
| [`weld/core/tracking_details_report.sql`](weld/core/tracking_details_report.sql) · [dbt](dbt/models/core/core_xero__tracking_details_report.sql) | Tracking Details Report | This template generates a report that brings together tracking details from journal and invoice records, outlining essential details including source type, source ID, and financial particulars such as net and gross amounts, tax details, and tracking categories. |

## Where these come from

These started as the templates in the weld.app template library. Each one was
published as a single query rather than a layered model set. Every query was
reviewed when it moved here and corrected where it was wrong; the corrections
are listed under Changes from the website version. The layout:

- Queries that hold report logic sit in `weld/core/`, each with a `SELECT *`
  passthrough in `weld/analytics/` for dashboards to bind to.
- Most queries read the raw tables directly, so there is no staging layer of
  cast-and-rename wrappers like the one in [`shopify/`](../shopify/).
- None of them has been reconciled against the source system. Treat every model
  as a starting point and check the output before relying on it.
- `dbt/` holds the same SQL with `{{ source() }}` / `{{ ref() }}` refs. No dbt
  tests ship with these models.

## Changes from the website version

Corrected in review:

- `core/monthly_sales_report` reads `{{raw.xero.invoice_line_item}}` and `{{raw.xero.invoice}}` instead of bare table names. It also keeps to approved and paid sales invoices (type ACCREC), leaving out drafts, voided invoices and supplier bills, and splits revenue by invoice currency.
- `core/journal_entries_report` counts entries with `count(distinct journal_id)` and lines from the journal line table; the website version counted both per line.

## Required tables

| Model | Raw tables |
|---|---|
| `core/invoice_entries_report` | `xero.invoice_line_item`, `xero.invoice` |
| `core/journal_entries_report` | `xero.journal_line`, `xero.journal` |
| `core/monthly_invoice_summary_report` | `xero.invoice` |
| `core/monthly_sales_report` | none |
| `core/tracking_details_report` | `xero.invoice_line_item`, `xero.journal_line` |

## Models

### Invoice Entries Report

`weld/core/invoice_entries_report.sql`

Leveraging SQL’s EXTRACT function, this template helps in extracting detailed data
on Xero invoice entries by segregating it based on the year and month. The report
encompasses vital details of each invoice including invoice ID, description,
quantity, unit amount, tax type, and much more. It not only facilitates a meticulous
representation of each entry but also empowers users to have a streamlined access to
exhaustive data, promoting informed decision-making in financial management and
reporting.

### Journal Entries Report

`weld/core/journal_entries_report.sql`

By extracting and aggregating Xero journal data based on year and month, this SQL
template aids in the streamlined reporting of accounting information. The report
brings forth a clear picture of the number of journal entries and journal lines
created each month, helping to track the accounting activities over time. It
leverages SQL's EXTRACT function and conditional aggregation to yield a structured
breakdown of the journal entries, providing a comprehensive view that can support
better financial management and reporting.

### Monthly Invoice Summary Report

`weld/core/monthly_invoice_summary_report.sql`

Utilizing Xero invoice data, this SQL template aggregates key invoice metrics on a
monthly basis, aiding in the detailed and comprehensive reporting of financial
information. It showcases a summary of invoicing activities per month including the
total and distinct count of invoices, accumulation of sub-total, tax, and total
amounts, along with tracking the amount due, paid, and credited. Moreover, it gives
insight into the client reach by reporting the number of unique contacts involved
each month. By leveraging SQL’s aggregation and date extraction functions, it
presents a structured report facilitating better financial monitoring and decision-
making.

### Monthly Sales Report

`weld/core/monthly_sales_report.sql`

The SQL template facilitates an in-depth exploration of monthly sales performance by
disaggregating the data to the level of individual products/services and item codes.
Leveraging SQL's EXTRACT function to derive the year and month from the invoice
date, it methodically groups the data to present a detailed account of the number of
sales and the monthly revenue for each product or service. By ordering the output by
year, month, and monthly revenue in descending order, it ensures that users can
quickly pinpoint the highest-grossing products or services in any given period,
fostering data-driven decision-making in business strategies.

### Tracking Details Report

`weld/core/tracking_details_report.sql`

This SQL template creates a unified view of tracking details stemming from both
journal and invoice records in the Xero accounting system. Utilizing Common Table
Expressions (CTEs) to segregate data from journal lines and invoice line items
separately, it then combines them to present a holistic report. This detailed report
not only outlines the financial particulars such as net amount, gross amount, and
tax details but also categorizes them based on their source, aiding in a
comprehensive and streamlined financial tracking and reporting.
