-- analytics__xero_monthly_invoice_summary_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_xero__monthly_invoice_summary_report') }}
