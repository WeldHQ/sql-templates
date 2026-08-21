-- analytics.amazon_vendor.forecast_vs_actuals
-- BI-facing contract over the core model. Deliberately thin.
--
-- The point is not transformation, it is indirection: dashboards, scheduled reports
-- and reverse-ETL syncs bind to this name, so core can be refactored - renamed
-- columns, changed grain, split into pieces - without breaking anything downstream.
-- Add the shaping your BI tool wants here rather than in core.

-- IN_PROGRESS windows are excluded: their actuals are real but incomplete, so every
-- error column reads as a large miss when the period simply has not finished. Forward
-- FORECAST rows are kept - the forecast for next month is the most useful thing in
-- this model.
SELECT *
FROM {{core.amazon_vendor.forecast_vs_actuals}}
WHERE forecast_status IN ('FORECAST', 'REALISED')
