-- analytics__tiktok_shop_sales_over_time
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_tiktok_shop__sales_over_time') }}
