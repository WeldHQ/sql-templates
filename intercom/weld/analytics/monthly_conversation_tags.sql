-- analytics.intercom.monthly_conversation_tags
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.intercom.monthly_conversation_tags}}
