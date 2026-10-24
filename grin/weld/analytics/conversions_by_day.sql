-- analytics.grin.conversions_by_day
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

SELECT * FROM {{core.grin.conversions_by_day}}
