-- analytics__stripe_mrr_time_series
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_stripe__mrr_time_series') }}
