-- analytics.pager_duty.responder_load_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.pager_duty.responder_load_daily}}
