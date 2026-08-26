-- analytics.amazon_seller.inventory_health
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- Inactive listings are kept: stock sitting against a closed listing is exactly the
-- dead inventory this model exists to surface, and filtering it out hides the
-- problem.
SELECT *
FROM {{core.amazon_seller.inventory_health}}
