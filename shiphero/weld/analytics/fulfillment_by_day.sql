-- analytics.shiphero.fulfillment_by_day
-- BI-facing contract over the core model. Bind dashboards here, not to core, so
-- core can be renamed or re-grained without breaking anything downstream.

SELECT * FROM {{core.shiphero.fulfillment_by_day}}
