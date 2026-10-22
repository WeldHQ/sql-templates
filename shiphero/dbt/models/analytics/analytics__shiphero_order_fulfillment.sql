-- analytics__shiphero_order_fulfillment
-- BI-facing contract over the core model. See analytics/fulfillment_by_day.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_shiphero__order_fulfillment') }}
