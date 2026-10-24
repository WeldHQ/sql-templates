-- analytics.intercom.monthly_ticket_by_state
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.intercom.monthly_ticket_by_state}}
