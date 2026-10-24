-- analytics__adyen_fees_by_payment_method
-- BI-facing contract over the core model. Dashboards bind here so the core model
-- can be renamed, re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_adyen__fees_by_payment_method') }}
