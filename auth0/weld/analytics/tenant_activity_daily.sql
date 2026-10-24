-- analytics.auth0.tenant_activity_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.auth0.tenant_activity_daily}}
