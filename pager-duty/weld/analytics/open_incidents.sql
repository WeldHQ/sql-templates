-- analytics.pager_duty.open_incidents
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.pager_duty.open_incidents}}
