-- analytics__netvisor_trial_balance_by_month
-- BI-facing contract over the core model. Dashboards bind here so the core model can
-- be renamed, re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_netvisor__trial_balance_by_month') }}
