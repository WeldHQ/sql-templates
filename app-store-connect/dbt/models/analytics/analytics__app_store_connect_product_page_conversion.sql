-- analytics__app_store_connect_product_page_conversion
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_app_store_connect__product_page_conversion') }}
