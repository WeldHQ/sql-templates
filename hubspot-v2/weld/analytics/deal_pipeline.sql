-- analytics.hubspot_v2.deal_pipeline
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.hubspot_v2.deal_pipeline}}
