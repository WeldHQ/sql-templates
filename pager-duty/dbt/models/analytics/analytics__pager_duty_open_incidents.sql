-- analytics__pager_duty_open_incidents
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_pager_duty__open_incidents') }}
