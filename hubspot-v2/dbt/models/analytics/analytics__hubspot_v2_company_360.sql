-- analytics__hubspot_v2_company_360
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot_v2__company_360') }}
