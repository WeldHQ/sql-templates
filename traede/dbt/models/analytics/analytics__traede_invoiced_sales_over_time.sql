-- analytics__traede_invoiced_sales_over_time
-- BI-facing contract over the core model. Bind dashboards here, not to core, so
-- core can be renamed or re-grained without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_traede__invoiced_sales_over_time') }}
