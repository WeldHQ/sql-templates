-- analytics.launchdarkly.flag_inventory
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.launchdarkly.flag_inventory}}
