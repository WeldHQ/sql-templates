-- analytics__chargebee_mrr_by_customer_month
-- BI-facing contract over the core model. See ../README.md for why this layer
-- exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_chargebee__mrr_by_customer_month') }}
