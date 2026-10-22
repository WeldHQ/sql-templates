-- analytics.gorgias.voice_calls_by_day
-- BI-facing contract over the core model. See analytics/ticket_lifecycle.sql for
-- why this layer exists even when it is a passthrough.

SELECT * FROM {{core.gorgias.voice_calls_by_day}}
