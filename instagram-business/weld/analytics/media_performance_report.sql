-- analytics.instagram_business.media_performance_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.instagram_business.media_performance_report}}
