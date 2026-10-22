-- analytics__hubspot_deals_by_deal_stage
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot__deals_by_deal_stage') }}
