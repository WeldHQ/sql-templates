-- analytics__shiphero_warehouse_productivity
-- BI-facing contract over the core model. See analytics/fulfillment_by_day.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_shiphero__warehouse_productivity') }}
