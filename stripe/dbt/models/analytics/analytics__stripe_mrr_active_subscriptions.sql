-- analytics__stripe_mrr_active_subscriptions
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_stripe__mrr_active_subscriptions') }}
