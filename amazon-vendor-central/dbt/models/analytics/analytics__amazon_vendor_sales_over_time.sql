-- analytics__amazon_vendor_sales_over_time
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- ONE DISTRIBUTOR VIEW, ENFORCED HERE. Core keeps all four report variants because
-- they are legitimately different questions, but a dashboard that sums across them
-- double-counts, and the person building the dashboard will not know that. So the
-- filter lives in the contract rather than in a chart definition.
--
-- MANUFACTURING + RETAIL is "how is my brand selling on Amazon". Change it here, in
-- one place, if your business is genuinely a SOURCING or BUSINESS story - and build a
-- second analytics model rather than removing the filter if you need both.

{{ config(materialized='view') }}
SELECT *
FROM {{ ref('core_amazon_vendor__sales_over_time') }}
WHERE distributor_view = 'MANUFACTURING'
  AND selling_program  = 'RETAIL'
