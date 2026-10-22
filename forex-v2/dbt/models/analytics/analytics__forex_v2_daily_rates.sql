-- analytics__forex_v2_daily_rates
-- BI-facing contract over the core model. Dashboards and other templates bind here
-- so the core model can be renamed, re-grained or split without breaking anything
-- downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_forex_v2__daily_rates') }}
