-- analytics__hubspot_closed_won_deals_amount_by_owner
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot__closed_won_deals_amount_by_owner') }}
