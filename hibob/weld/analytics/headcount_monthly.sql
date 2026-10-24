-- analytics.hibob.headcount_monthly
-- BI-facing contract over the core model. See shopify/weld/analytics/sales_over_time.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.hibob.headcount_monthly}}
