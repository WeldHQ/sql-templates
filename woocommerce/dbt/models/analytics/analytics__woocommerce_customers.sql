-- analytics__woocommerce_customers
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_woocommerce__customers') }}
