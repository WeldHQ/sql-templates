-- analytics.instagram_business.engagement_metric_analysis
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.instagram_business.engagement_metric_analysis}}
