-- analytics__zoho_crm_deal_flow_by_month
-- BI-facing contract over the core model. See analytics/deal_pipeline.sql for why
-- this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_zoho_crm__deal_flow_by_month') }}
