-- analytics__amazon_mws_monthly_financial_analysis
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_amazon_mws__monthly_financial_analysis') }}
