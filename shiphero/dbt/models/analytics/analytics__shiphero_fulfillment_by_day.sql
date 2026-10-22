-- analytics__shiphero_fulfillment_by_day
-- BI-facing contract over the core model. Bind dashboards here, not to core, so
-- core can be renamed or re-grained without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_shiphero__fulfillment_by_day') }}
