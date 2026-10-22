-- analytics.stripe.mrr_normalization
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.stripe.mrr_normalization}}
