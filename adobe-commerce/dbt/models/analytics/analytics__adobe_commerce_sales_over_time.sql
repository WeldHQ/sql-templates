-- analytics__adobe_commerce_sales_over_time
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_adobe_commerce__sales_over_time') }}
