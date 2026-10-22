-- analytics__adobe_commerce_inventory_cover
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_adobe_commerce__inventory_cover') }}
