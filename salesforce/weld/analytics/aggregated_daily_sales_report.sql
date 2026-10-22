-- analytics.salesforce.aggregated_daily_sales_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.salesforce.aggregated_daily_sales_report}}
