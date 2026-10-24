-- analytics.intercom.monthly_ticket_resolution_time
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.intercom.monthly_ticket_resolution_time}}
