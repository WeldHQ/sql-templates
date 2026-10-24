-- analytics__app_store_connect_sales_and_proceeds
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_app_store_connect__sales_and_proceeds') }}
