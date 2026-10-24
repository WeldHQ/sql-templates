-- analytics.clickup.task_dependency_analysis
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.clickup.task_dependency_analysis}}
