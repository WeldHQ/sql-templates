-- analytics.clickup.user_activity_and_performance_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.clickup.user_activity_and_performance_report}}
