-- analytics__business_central_receivables_aging
-- BI-facing contract over the core model. Dashboards bind here so the core model can
-- be renamed, re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_business_central__receivables_aging') }}
