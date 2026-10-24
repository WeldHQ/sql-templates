-- analytics__walmart_settlement_ledger
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_walmart__settlement_ledger') }}
