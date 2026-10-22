-- analytics__amazon_mws_monthly_shipping_and_delivery_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_amazon_mws__monthly_shipping_and_delivery_report') }}
