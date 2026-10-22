-- analytics.launchdarkly.context_activity
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.launchdarkly.context_activity}}
