-- analytics.google_analytics_4.channel_traffic_overview
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.google_analytics_4.channel_traffic_overview}}
