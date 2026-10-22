-- analytics.hubspot_v2.company_360
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.hubspot_v2.company_360}}
