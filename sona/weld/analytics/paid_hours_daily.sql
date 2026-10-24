-- analytics.sona.paid_hours_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.sona.paid_hours_daily}}
