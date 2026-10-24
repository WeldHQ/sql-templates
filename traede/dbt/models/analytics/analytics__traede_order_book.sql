-- analytics__traede_order_book
-- BI-facing contract over the core model. See analytics/invoiced_sales_over_time.sql
-- for why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_traede__order_book') }}
