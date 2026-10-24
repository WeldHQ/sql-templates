-- analytics.sona.shift_coverage_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.sona.shift_coverage_daily}}
