-- analytics__daisycon_invoice_costs_monthly
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_daisycon__invoice_costs_monthly') }}
