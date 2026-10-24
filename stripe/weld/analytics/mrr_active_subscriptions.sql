-- analytics.stripe.mrr_active_subscriptions
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

SELECT * FROM {{core.stripe.mrr_active_subscriptions}}
