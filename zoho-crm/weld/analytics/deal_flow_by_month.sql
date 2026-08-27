-- analytics.zoho_crm.deal_flow_by_month
-- BI-facing contract over the core model. See analytics/deal_pipeline.sql for why
-- this layer exists even when it is a passthrough.

SELECT * FROM {{core.zoho_crm.deal_flow_by_month}}
