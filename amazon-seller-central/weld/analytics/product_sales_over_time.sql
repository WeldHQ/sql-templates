-- analytics.amazon_seller.product_sales_over_time
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- Cancelled lines are excluded here rather than in core: core keeps them because
-- Amazon's own ordered_product_sales nets cancellations out on the original order
-- date, and a model that cannot see them cannot reproduce that. A dashboard showing
-- a cancelled line as a sale is just misleading.
SELECT *
FROM {{core.amazon_seller.product_sales_over_time}}
WHERE NOT has_cancelled_line
