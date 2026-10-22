-- analytics.economic.invoice_line_items
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.economic.invoice_line_items}}
