-- analytics.clickup.monthly_time_tracking_and_billing_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.clickup.monthly_time_tracking_and_billing_report}}
