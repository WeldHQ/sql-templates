-- analytics.xero.monthly_invoice_summary_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.xero.monthly_invoice_summary_report}}
