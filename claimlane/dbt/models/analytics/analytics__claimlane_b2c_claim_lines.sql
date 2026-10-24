-- analytics__claimlane_b2c_claim_lines
-- BI-facing contract over the core model. See analytics/b2c_claims_by_month.sql
-- for why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_claimlane__b2c_claim_lines') }}
