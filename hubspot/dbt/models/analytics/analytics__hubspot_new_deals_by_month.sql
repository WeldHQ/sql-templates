-- analytics__hubspot_new_deals_by_month
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot__new_deals_by_month') }}
