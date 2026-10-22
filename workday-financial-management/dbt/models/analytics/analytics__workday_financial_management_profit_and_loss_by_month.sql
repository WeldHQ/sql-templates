-- analytics__workday_financial_management_profit_and_loss_by_month
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_workday_financial_management__profit_and_loss_by_month') }}
