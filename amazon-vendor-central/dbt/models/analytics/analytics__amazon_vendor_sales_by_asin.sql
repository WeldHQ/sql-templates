-- analytics__amazon_vendor_sales_by_asin
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- Single distributor view, same reason as vendor_sales_over_time - and here it also
-- fixes the traffic join. Glance views are reported per ASIN per day, not per view,
-- so they repeat across the four variants; filtering to one is what makes
-- SUM(glance_views) and every conversion rate correct.

{{ config(materialized='view') }}
SELECT *
FROM {{ ref('core_amazon_vendor__sales_by_asin') }}
WHERE distributor_view = 'MANUFACTURING'
  AND selling_program  = 'RETAIL'
