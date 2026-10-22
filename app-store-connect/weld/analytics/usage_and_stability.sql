-- analytics.app_store_connect.usage_and_stability
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.app_store_connect.usage_and_stability}}
