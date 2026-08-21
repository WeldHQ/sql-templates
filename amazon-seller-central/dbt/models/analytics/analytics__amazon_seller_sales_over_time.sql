-- analytics__amazon_seller_sales_over_time
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

{{ config(materialized='view') }}

SELECT *
FROM {{ ref('core_amazon_seller__sales_over_time') }}
