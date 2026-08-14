-- analytics.shopify.sales_over_time
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled
-- reports and reverse-ETL syncs bind to this name, so core can be refactored -
-- renamed columns, changed grain, split into pieces - without breaking anything
-- downstream. Add the shaping your BI tool wants here rather than in core.

-- Cancelled orders are excluded here rather than in core: core keeps them so
-- their reversal events still land, and a report that shows a cancelled order's
-- sale without context is misleading. Voided orders are already gone in core.
-- Pending payments are deliberately kept - Shopify counts them as sales.
SELECT *
FROM {{core.shopify.sales_over_time}}
WHERE cancelled_at IS NULL
