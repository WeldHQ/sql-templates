-- analytics__hubspot_new_companies_by_month
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot__new_companies_by_month') }}
