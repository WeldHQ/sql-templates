-- analytics.daisycon.invoice_costs_monthly
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

SELECT * FROM {{core.daisycon.invoice_costs_monthly}}
