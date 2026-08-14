-- analytics__shopify_sales_by_product
-- BI-facing contract over the core model. See analytics/sales_over_time.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_shopify__sales_by_product') }}
