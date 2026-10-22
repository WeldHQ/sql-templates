-- analytics.klaviyo.monthly_flow_events
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.klaviyo.monthly_flow_events}}
