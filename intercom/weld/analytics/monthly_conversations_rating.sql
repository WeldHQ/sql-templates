-- analytics.intercom.monthly_conversations_rating
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.intercom.monthly_conversations_rating}}
