-- analytics.google_analytics_4.event_performance
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.google_analytics_4.event_performance}}
