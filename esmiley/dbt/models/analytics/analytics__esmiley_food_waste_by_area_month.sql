-- analytics__esmiley_food_waste_by_area_month
-- BI-facing contract over the core model. See shopify/weld/analytics/sales_over_time.sql
-- for why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_esmiley__food_waste_by_area_month') }}
