-- analytics.zendesk.ticket_volume_by_day
-- BI-facing contract over the core model. See analytics/ticket_lifecycle.sql for
-- why this layer exists even when it is a passthrough.

SELECT * FROM {{core.zendesk.ticket_volume_by_day}}
