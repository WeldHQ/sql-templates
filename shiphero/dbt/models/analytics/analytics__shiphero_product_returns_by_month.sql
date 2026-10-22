-- analytics__shiphero_product_returns_by_month
-- BI-facing contract over the core model. See analytics/fulfillment_by_day.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_shiphero__product_returns_by_month') }}
