-- analytics.amazon_seller.asin_profitability
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- Trailing adjustments are kept - a fee or reimbursement posting after the sale is
-- not an error, and excluding it would overstate margin by exactly the amount that
-- arrived late. Aggregate over a month before reading any margin column; a single
-- day's contribution is a cash-flow event, not a margin.
SELECT *
FROM {{core.amazon_seller.asin_profitability}}
