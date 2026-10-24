-- analytics.gorgias.agent_performance_by_month
-- BI-facing contract over the core model. See analytics/ticket_lifecycle.sql for
-- why this layer exists even when it is a passthrough.

SELECT * FROM {{core.gorgias.agent_performance_by_month}}
