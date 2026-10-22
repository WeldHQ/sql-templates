-- analytics.xero.tracking_details_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.xero.tracking_details_report}}
