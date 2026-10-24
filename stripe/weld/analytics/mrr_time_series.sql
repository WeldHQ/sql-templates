-- analytics.stripe.mrr_time_series
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.stripe.mrr_time_series}}
