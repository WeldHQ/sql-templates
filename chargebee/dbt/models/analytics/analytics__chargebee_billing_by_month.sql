-- analytics__chargebee_billing_by_month
-- BI-facing contract over the core model. See ../README.md for why this layer
-- exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_chargebee__billing_by_month') }}
